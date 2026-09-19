using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class CrisisService(
    ICrisisRepository crisisRepository,
    ICaseService caseService,
    IValidator<TriggerCrisisEventRequest> triggerValidator,
    IValidator<UpdateCrisisEventStatusRequest> statusValidator) : ICrisisService
{
    private const string FlagEmergencyAction = "FlagEmergency";
    private const string StabilizeAction = "Stabilize";

    public async Task<TriggerCrisisEventResponse> TriggerAsync(
        TriggerCrisisEventRequest request, Func<string, bool> hasPermission,
        int performedBy, string ipAddress)
    {
        await triggerValidator.ValidateAndThrowAsync(request);

        var (eventId, _) = await crisisRepository.TriggerAsync(
            request.CaseId, request.CrisisTypeCode.ToUpperInvariant(),
            request.Severity.ToUpperInvariant(), request.TriggerSource.ToUpperInvariant(),
            request.Notes, performedBy, ipAddress);

        // Best-effort emergency routing: the event and its Immediate Alert
        // are already persisted; transition failures never roll them back.
        var (transitionApplied, transitionNote) = await TryApplyTransitionAsync(
            request.CaseId, FlagEmergencyAction,
            $"Crisis event #{eventId} triggered manually ({request.CrisisTypeCode}, {request.Severity}).",
            hasPermission, performedBy, ipAddress);

        var @event = await crisisRepository.GetByIdAsync(eventId);
        return new TriggerCrisisEventResponse(@event.ToDto(), transitionApplied, transitionNote);
    }

    public async Task<UpdateCrisisEventStatusResponse> UpdateStatusAsync(
        int crisisEventId, UpdateCrisisEventStatusRequest request,
        Func<string, bool> hasPermission, int performedBy, string ipAddress)
    {
        await statusValidator.ValidateAndThrowAsync(request);

        var newStatus = request.NewStatus.ToUpperInvariant();
        var (caseId, caseRowVersion) = await crisisRepository.UpdateStatusAsync(
            crisisEventId, newStatus, request.RowVersion, performedBy, ipAddress);

        // S7g "Stabilized? = Yes" -> S7h: return to the clinical pathway.
        // CONTINUE_CARE (S7i) keeps the case on the emergency branch, so
        // no workflow transition is attempted.
        var transitionApplied = false;
        string? transitionNote = null;
        if (newStatus == "STABILIZED")
        {
            (transitionApplied, transitionNote) = await TryStabilizeAsync(
                caseId, caseRowVersion, crisisEventId,
                hasPermission, performedBy, ipAddress);
        }

        var @event = await crisisRepository.GetByIdAsync(crisisEventId);
        return new UpdateCrisisEventStatusResponse(@event.ToDto(), transitionApplied, transitionNote);
    }

    public async Task<IReadOnlyList<CrisisEventDto>> GetByCaseAsync(int caseId)
    {
        var events = await crisisRepository.GetByCaseAsync(caseId);
        return events.Select(e => e.ToDto()).ToList();
    }

    public async Task<IReadOnlyList<CrisisTypeDto>> GetTypesAsync()
    {
        var types = await crisisRepository.GetTypesAsync();
        return types.Select(t => t.ToDto()).ToList();
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

    private async Task<(bool Applied, string? Note)> TryStabilizeAsync(
        int caseId, byte[] caseRowVersion, int crisisEventId,
        Func<string, bool> hasPermission, int performedBy, string ipAddress)
    {
        try
        {
            var transition = new ApplyTransitionRequest(
                StabilizeAction,
                $"Crisis event #{crisisEventId} stabilized (S7g -> S7h: return to clinical pathway).",
                null,
                caseRowVersion);
            await caseService.ApplyTransitionAsync(caseId, transition, hasPermission, performedBy, ipAddress);
            return (true, $"Case transitioned to TRIAGE ({StabilizeAction}).");
        }
        catch (Exception ex) when (ex is NotFoundException
            or WorkflowException or ConcurrencyException or ForbiddenException)
        {
            return (false, $"Stabilize transition not applied: {ex.Message}");
        }
    }
}
