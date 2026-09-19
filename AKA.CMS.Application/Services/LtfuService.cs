using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class LtfuService(
    IFollowUpRepository followUpRepository,
    ICaseService caseService,
    IValidator<ReEngageLtfuRequest> reEngageValidator) : ILtfuService
{
    private const string RecordMissedVisitAction = "RecordMissedVisit";
    private const string ReEngageAction = "ReEngage";

    public async Task<EvaluateLtfuResponse> EvaluateAsync(
        int caseId, Func<string, bool> hasPermission,
        int performedBy, string ipAddress)
    {
        var (declared, _) = await followUpRepository.FlagLtfuAsync(
            caseId, performedBy, ipAddress);

        var transitionApplied = false;
        string? transitionNote = null;
        if (declared)
        {
            (transitionApplied, transitionNote) = await TryApplyTransitionAsync(
                caseId, RecordMissedVisitAction,
                "LTFU declared by evaluation (S33b).",
                hasPermission, performedBy, ipAddress);
        }
        else
        {
            transitionNote = "LTFU threshold not reached or case already flagged.";
        }

        var tracking = await followUpRepository.GetLtfuByCaseAsync(caseId)
            ?? throw new NotFoundException($"No LTFU tracking found for case {caseId}.");
        return new EvaluateLtfuResponse(
            tracking.ToDto(), declared, transitionApplied, transitionNote);
    }

    public async Task<ReEngageLtfuResponse> ReEngageAsync(
        int caseId, ReEngageLtfuRequest request,
        Func<string, bool> hasPermission, int performedBy, string ipAddress)
    {
        await reEngageValidator.ValidateAndThrowAsync(request);

        await followUpRepository.ReEngageLtfuAsync(
            caseId, request.ReEngagementNotes, performedBy, ipAddress);

        var (transitionApplied, transitionNote) = await TryApplyTransitionAsync(
            caseId, ReEngageAction,
            "Case re-engaged after LTFU (S33d: supervisor review & re-engagement).",
            hasPermission, performedBy, ipAddress);

        var tracking = await followUpRepository.GetLtfuByCaseAsync(caseId)
            ?? throw new NotFoundException($"No LTFU tracking found for case {caseId}.");
        return new ReEngageLtfuResponse(
            tracking.ToDto(), transitionApplied, transitionNote);
    }

    public async Task<LostToFollowUpDto?> GetByCaseAsync(int caseId)
    {
        var tracking = await followUpRepository.GetLtfuByCaseAsync(caseId);
        return tracking?.ToDto();
    }

    private async Task<(bool Applied, string? Note)> TryApplyTransitionAsync(
        int caseId, string actionCode, string comment,
        Func<string, bool> hasPermission, int performedBy, string ipAddress)
    {
        try
        {
            var @case = await caseService.GetByIdAsync(caseId);
            var transition = new ApplyTransitionRequest(actionCode, comment, null, @case.RowVersion);
            await caseService.ApplyTransitionAsync(caseId, transition, hasPermission, performedBy, ipAddress);
            return (true, $"Case auto-transitioned ({actionCode}).");
        }
        catch (Exception ex) when (ex is NotFoundException
            or WorkflowException or ConcurrencyException or ForbiddenException)
        {
            return (false, $"Auto-transition not applied: {ex.Message}");
        }
    }
}
