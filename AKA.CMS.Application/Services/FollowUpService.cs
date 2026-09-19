using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class FollowUpService(
    IFollowUpRepository followUpRepository,
    ICaseService caseService,
    IValidator<ScheduleFollowUpRequest> scheduleValidator,
    IValidator<RecordFollowUpOutcomeRequest> outcomeValidator) : IFollowUpService
{
    private const string ScheduleFollowUpAction = "ScheduleFollowUp";
    private const string ContinueFollowUpAction = "ContinueFollowUp";
    private const string RecordMissedVisitAction = "RecordMissedVisit";

    public async Task<ScheduleFollowUpResponse> ScheduleAsync(
        ScheduleFollowUpRequest request, Func<string, bool> hasPermission,
        int performedBy, string ipAddress)
    {
        await scheduleValidator.ValidateAndThrowAsync(request);

        var followUpId = await followUpRepository.ScheduleAsync(
            request.CaseId, request.ScheduledDate, request.FollowUpType,
            request.AssignedToUserId, request.Notes, performedBy, ipAddress);

        var (transitionApplied, transitionNote) = await TryApplyTransitionAsync(
            request.CaseId, ScheduleFollowUpAction,
            $"Follow-up #{followUpId} scheduled ({request.FollowUpType}).",
            hasPermission, performedBy, ipAddress);

        var followUp = (await followUpRepository.GetByCaseAsync(request.CaseId))
            .First(f => f.FollowUpId == followUpId);
        return new ScheduleFollowUpResponse(
            followUp.ToDto(), transitionApplied, transitionNote);
    }

    public async Task<RecordFollowUpOutcomeResponse> RecordOutcomeAsync(
        int followUpId, RecordFollowUpOutcomeRequest request,
        Func<string, bool> hasPermission, int performedBy, string ipAddress)
    {
        await outcomeValidator.ValidateAndThrowAsync(request);

        var outcome = request.Outcome.ToUpperInvariant();
        var (caseId, caseRowVersion) = await followUpRepository.RecordOutcomeAsync(
            followUpId, outcome, request.OutcomeNotes, request.ActualDate,
            request.RowVersion, performedBy, ipAddress);

        var ltfuDeclared = false;
        var transitionApplied = false;
        string? transitionNote = null;

        if (outcome == "MISSED")
        {
            (ltfuDeclared, _) = await followUpRepository.FlagLtfuAsync(
                caseId, performedBy, ipAddress);

            if (ltfuDeclared)
            {
                (transitionApplied, transitionNote) = await TryApplyTransitionAsync(
                    caseId, RecordMissedVisitAction,
                    $"Follow-up #{followUpId} missed; LTFU threshold reached (S33b).",
                    hasPermission, performedBy, ipAddress);
            }
            else
            {
                transitionNote = "LTFU threshold not reached; case remains in follow-up.";
            }
        }
        else if (outcome == "COMPLETED")
        {
            (transitionApplied, transitionNote) = await TryApplyTransitionAsync(
                caseId, ContinueFollowUpAction,
                $"Follow-up #{followUpId} attended (S33a: continue care plan).",
                hasPermission, performedBy, ipAddress);
        }

        var followUp = (await followUpRepository.GetByCaseAsync(caseId))
            .First(f => f.FollowUpId == followUpId);
        return new RecordFollowUpOutcomeResponse(
            followUp.ToDto(), ltfuDeclared, transitionApplied, transitionNote);
    }

    public async Task<IReadOnlyList<FollowUpDto>> GetByCaseAsync(int caseId)
    {
        var followUps = await followUpRepository.GetByCaseAsync(caseId);
        return followUps.Select(f => f.ToDto()).ToList();
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
