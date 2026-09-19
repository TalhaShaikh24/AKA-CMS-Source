using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class CaseClosureService(
    ICaseClosureRepository closureRepository,
    ICaseService caseService,
    IValidator<RequestCaseClosureRequest> requestValidator,
    IValidator<ApproveCaseClosureRequest> approveValidator) : ICaseClosureService
{
    private const string CloseCaseAction = "CloseCase";
    private const string CloseEmergencyCareAction = "CloseEmergencyCare";

    public async Task<CaseClosureDto> RequestClosureAsync(
        RequestCaseClosureRequest request, int performedBy, string ipAddress)
    {
        await requestValidator.ValidateAndThrowAsync(request);

        var closureId = await closureRepository.RequestClosureAsync(
            request.CaseId, request.ClosureReason, request.SymptomRemission,
            request.ClosureSummary, performedBy, performedBy, ipAddress);

        var closure = (await closureRepository.GetByCaseAsync(request.CaseId))
            .First(c => c.ClosureId == closureId);
        return closure.ToDto();
    }

    public async Task<ApproveCaseClosureResponse> ApproveClosureAsync(
        int closureId, ApproveCaseClosureRequest request,
        Func<string, bool> hasPermission, int performedBy, string ipAddress)
    {
        await approveValidator.ValidateAndThrowAsync(request);

        var (caseId, _) = await closureRepository.ApproveClosureAsync(
            closureId, request.Approve, request.RejectionReason,
            performedBy, request.RowVersion, performedBy, ipAddress);

        var transitionApplied = false;
        string? transitionNote = null;
        if (request.Approve)
        {
            (transitionApplied, transitionNote) = await TryApplyTransitionAsync(
                caseId, CloseCaseAction,
                $"Closure request #{closureId} approved by supervisor (S34b).",
                hasPermission, performedBy, ipAddress);

            if (!transitionApplied)
            {
                (transitionApplied, transitionNote) = await TryApplyTransitionAsync(
                    caseId, CloseEmergencyCareAction,
                    $"Closure request #{closureId} approved by supervisor (emergency care closed).",
                    hasPermission, performedBy, ipAddress);
            }
        }

        var closure = (await closureRepository.GetByCaseAsync(caseId))
            .First(c => c.ClosureId == closureId);
        return new ApproveCaseClosureResponse(
            closure.ToDto(), transitionApplied, transitionNote);
    }

    public async Task<IReadOnlyList<CaseClosureDto>> GetByCaseAsync(int caseId)
    {
        var closures = await closureRepository.GetByCaseAsync(caseId);
        return closures.Select(c => c.ToDto()).ToList();
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
