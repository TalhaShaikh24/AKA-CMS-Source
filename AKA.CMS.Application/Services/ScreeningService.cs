using System.Text.Json;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class ScreeningService(
    IScreeningRepository screeningRepository,
    ICaseService caseService,
    IValidator<SubmitScreeningRequest> submitValidator) : IScreeningService
{
    private const string SevereRiskLevel = "SEVERE";
    private const string FlagEmergencyAction = "FlagEmergency";

    public async Task<IReadOnlyList<ScreeningToolDto>> GetToolsAsync()
    {
        var tools = await screeningRepository.GetToolsAsync();
        return tools.Select(t => t.ToDto()).ToList();
    }

    public async Task<SubmitScreeningResponse> SubmitAsync(
        SubmitScreeningRequest request, Func<string, bool> hasPermission,
        int performedBy, string ipAddress)
    {
        await submitValidator.ValidateAndThrowAsync(request);

        var itemScoresJson = JsonSerializer.Serialize(request.ItemScores);

        var screening = await screeningRepository.SubmitAsync(
            request.CaseId, request.ToolCode.ToUpperInvariant(), itemScoresJson,
            performedBy, ipAddress);

        var autoApplied = false;
        string? autoNote = null;

        // Workflow step S15: severe risk auto-escalates to the emergency
        // path. Best-effort: the screening is already persisted; if the
        // transition is not available from the case's current state (or
        // permission/row-version prevents it), we record a note instead.
        if (screening.RiskLevel.Equals(SevereRiskLevel, StringComparison.OrdinalIgnoreCase))
        {
            (autoApplied, autoNote) = await TryFlagEmergencyAsync(
                request.CaseId, screening.ToolCode, screening.RawScore,
                hasPermission, performedBy, ipAddress);
        }

        return new SubmitScreeningResponse(screening.ToDto(), autoApplied, autoNote);
    }

    public async Task<IReadOnlyList<ScreeningDto>> GetByCaseAsync(int caseId)
    {
        var screenings = await screeningRepository.GetByCaseAsync(caseId);
        return screenings.Select(s => s.ToDto()).ToList();
    }

    private async Task<(bool Applied, string? Note)> TryFlagEmergencyAsync(
        int caseId, string toolCode, int rawScore,
        Func<string, bool> hasPermission, int performedBy, string ipAddress)
    {
        try
        {
            var @case = await caseService.GetByIdAsync(caseId);
            var transition = new ApplyTransitionRequest(
                FlagEmergencyAction,
                $"Auto-escalated by screening: {toolCode} score {rawScore} (severe risk).",
                null,
                @case.RowVersion);
            await caseService.ApplyTransitionAsync(caseId, transition, hasPermission, performedBy, ipAddress);
            return (true, $"Case auto-transitioned to EMERGENCY ({FlagEmergencyAction}).");
        }
        catch (Exception ex) when (ex is NotFoundException
            or WorkflowException or ConcurrencyException or ForbiddenException)
        {
            return (false, $"Auto-escalation not applied: {ex.Message}");
        }
    }
}
