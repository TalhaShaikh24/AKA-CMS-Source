using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

/// <summary>
/// Implements the High/Moderate/Low risk branch logic from the workflow
/// sheet (S18-S25): the latest screening risk decides the routing rule,
/// which drives the care plan, assignment SLA, referral targets and
/// supervisor alerts.
/// </summary>
public sealed class AssignmentService(
    ICarePlanRepository carePlanRepository,
    IAssignmentQueueRepository queueRepository,
    IReferralRepository referralRepository,
    ICaseCommentRepository commentRepository,
    IScreeningRepository screeningRepository,
    ICaseService caseService,
    IValidator<RouteCaseRequest> routeValidator,
    IValidator<AssignQueueRequest> assignValidator) : IAssignmentService
{
    private const string SendReferralAction = "SendReferral";

    public async Task<RouteCaseResponse> RouteCaseAsync(
        RouteCaseRequest request, Func<string, bool> hasPermission,
        int performedBy, string ipAddress)
    {
        await routeValidator.ValidateAndThrowAsync(request);

        var riskCategory = request.RiskCategory is null
            ? await InferRiskCategoryAsync(request.CaseId)
            : request.RiskCategory.ToUpperInvariant();

        var rules = await carePlanRepository.GetRoutingRulesAsync();
        var rule = rules.FirstOrDefault(r => r.RiskCategory == riskCategory)
            ?? throw new InvalidDomainValueException(
                $"No routing rule for risk category '{riskCategory}'.");

        var slaDueAt = DateTime.UtcNow.AddHours(rule.SlaHours);

        // 1. Action care plan from the rule's workflow steps (S18-S22x + S25).
        var planId = await carePlanRepository.CreateAsync(
            request.CaseId, riskCategory, null, null, performedBy, ipAddress);

        // 2. Assignment queue with the rule's SLA.
        var queueId = await queueRepository.EnqueueAsync(
            request.CaseId, riskCategory, performedBy, ipAddress);

        // 3. Referrals per the rule's targets (workflow S21/S25).
        var referralIds = new List<int>();
        foreach (var target in rule.ReferralTargets
                     .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            referralIds.Add(await referralRepository.CreateAsync(
                request.CaseId, target, slaDueAt,
                $"{rule.DisplayName} risk auto-routing (S18-S25).",
                performedBy, ipAddress));
        }

        // 4. Supervisor alert for high-risk cases (workflow S23-High).
        if (rule.RequiresSupervisorAlert)
        {
            await commentRepository.AddAsync(request.CaseId, "ALERT",
                $"High-risk case routed: SLA {rule.SlaHours}h, referrals to {rule.ReferralTargets}. Supervisor review required (S23-High).",
                performedBy, ipAddress);
        }

        // 5. Best-effort workflow pairing: a routed case with referrals
        //    is on its way to REFERRAL_SENT; never fails the routing.
        var (transitionApplied, transitionNote) = await TrySendReferralAsync(
            request.CaseId, hasPermission, performedBy, ipAddress);

        return new RouteCaseResponse(
            riskCategory, slaDueAt, planId, queueId, referralIds,
            transitionApplied, transitionNote);
    }

    public async Task AssignAsync(
        int queueId, AssignQueueRequest request, int performedBy, string ipAddress)
    {
        await assignValidator.ValidateAndThrowAsync(request);

        await queueRepository.AssignAsync(
            queueId, request.AssignedToUserId, request.RowVersion,
            performedBy, ipAddress);
    }

    public async Task<IReadOnlyList<QueueEntryDto>> GetPendingAsync()
    {
        var entries = await queueRepository.GetPendingAsync();
        return entries.Select(e => e.ToDto()).ToList();
    }

    private async Task<string> InferRiskCategoryAsync(int caseId)
    {
        var screenings = await screeningRepository.GetByCaseAsync(caseId);
        var latest = screenings.OrderByDescending(s => s.ScreenedAt).FirstOrDefault()
            ?? throw new InvalidDomainValueException(
                "No screenings found for the case; pass an explicit risk category.");

        return latest.RiskLevel.ToUpperInvariant() switch
        {
            "SEVERE" or "MOD_SEVERE" => "HIGH",
            "MODERATE" => "MODERATE",
            "MILD" or "MINIMAL" => "LOW",
            var other => throw new InvalidDomainValueException(
                $"Unknown risk level '{other}'.")
        };
    }

    private async Task<(bool Applied, string? Note)> TrySendReferralAsync(
        int caseId, Func<string, bool> hasPermission,
        int performedBy, string ipAddress)
    {
        try
        {
            var @case = await caseService.GetByIdAsync(caseId);
            await caseService.ApplyTransitionAsync(caseId,
                new ApplyTransitionRequest(SendReferralAction,
                    "Auto-routed: referrals created per risk rule (S25).",
                    null, @case.RowVersion),
                hasPermission, performedBy, ipAddress);
            return (true, $"Case transitioned via '{SendReferralAction}'.");
        }
        catch (Exception ex) when (ex is NotFoundException
            or WorkflowException or ConcurrencyException or ForbiddenException)
        {
            return (false, $"Routing done, transition not applied: {ex.Message}");
        }
    }
}
