using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class HelplineService(
    IHelplineRepository helplineRepository,
    ICrisisDetectionService detectionService,
    ICaseService caseService,
    IValidator<LogHelplineCallRequest> logValidator) : IHelplineService
{
    private const string FlagEmergencyAction = "FlagEmergency";

    public async Task<LogHelplineCallResponse> LogCallAsync(
        LogHelplineCallRequest request, Func<string, bool> hasPermission,
        int performedBy, string ipAddress)
    {
        await logValidator.ValidateAndThrowAsync(request);

        var (typeCodesCsv, severity, indicatorsJson) = detectionService.Detect(request.Indicators);

        var (callId, crisisEventId, _) = await helplineRepository.LogCallAsync(
            request.CallerName, request.CallerPhone, request.CaseId,
            indicatorsJson, typeCodesCsv, severity,
            request.CallNotes, performedBy, ipAddress);

        // S7 = Yes: crisis event was created by the stored procedure.
        // Route the case to EMERGENCY via the workflow engine.
        // Best-effort: the call is already persisted; a transition that is
        // not allowed from the case's current state (or permission/
        // concurrency prevents it) is recorded as a note instead.
        var transitionApplied = false;
        string? transitionNote = null;
        if (crisisEventId.HasValue && request.CaseId.HasValue)
        {
            (transitionApplied, transitionNote) = await TryFlagEmergencyAsync(
                request.CaseId.Value, typeCodesCsv, severity!,
                hasPermission, performedBy, ipAddress);
        }

        var call = await helplineRepository.GetByIdAsync(callId);

        return new LogHelplineCallResponse(
            call.ToDto(), crisisEventId.HasValue, crisisEventId,
            transitionApplied, transitionNote);
    }

    public async Task<IReadOnlyList<HelplineCallDto>> GetCallsAsync(int? caseId, int top)
    {
        var calls = await helplineRepository.GetListAsync(caseId, top);
        return calls.Select(c => c.ToDto()).ToList();
    }

    private async Task<(bool Applied, string? Note)> TryFlagEmergencyAsync(
        int caseId, string typeCodesCsv, string severity,
        Func<string, bool> hasPermission, int performedBy, string ipAddress)
    {
        try
        {
            var @case = await caseService.GetByIdAsync(caseId);
            var transition = new ApplyTransitionRequest(
                FlagEmergencyAction,
                $"Auto-escalated by helpline crisis detection: {typeCodesCsv} (severity {severity}).",
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
