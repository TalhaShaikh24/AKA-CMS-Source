using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class ReferralService(
    IReferralRepository referralRepository,
    ICaseService caseService,
    IValidator<CreateReferralRequest> createValidator,
    IValidator<UpdateReferralStatusRequest> updateValidator) : IReferralService
{
    private const string AcceptReferralAction = "AcceptReferral";
    private const string RerouteReferralAction = "RerouteReferral";

    public async Task<ReferralDto> CreateAsync(
        CreateReferralRequest request, int performedBy, string ipAddress)
    {
        await createValidator.ValidateAndThrowAsync(request);

        var referralId = await referralRepository.CreateAsync(
            request.CaseId, request.ReferredTo.ToUpperInvariant(),
            request.SlaDueAt, request.Notes, performedBy, ipAddress);

        return (await referralRepository.GetByIdAsync(referralId)).ToDto();
    }

    public async Task<UpdateReferralStatusResponse> UpdateStatusAsync(
        int referralId, UpdateReferralStatusRequest request,
        Func<string, bool> hasPermission, int performedBy, string ipAddress)
    {
        await updateValidator.ValidateAndThrowAsync(request);

        var referral = await referralRepository.GetByIdAsync(referralId);

        var (newReferralId, status) = await referralRepository.UpdateStatusAsync(
            referralId, request.NewStatus.ToUpperInvariant(),
            request.RejectionReason, request.RowVersion, performedBy, ipAddress);

        string? note = null;

        // Pair with the workflow engine (workflow S25-S26): an accepted
        // referral moves the case to IN_TREATMENT; a rejected one is
        // re-routed within REFERRAL_SENT (RerouteReferral self-loop).
        // Best-effort: the referral is persisted; a failed transition
        // only produces a note.
        if (status == "ACCEPTED")
            note = await TryApplyTransitionAsync(referral.CaseId, AcceptReferralAction,
                $"Referral {referral.ReferralNumber} accepted.", hasPermission, performedBy, ipAddress);
        else if (status == "REJECTED")
            note = await TryApplyTransitionAsync(referral.CaseId, RerouteReferralAction,
                $"Referral {referral.ReferralNumber} rejected and re-routed.", hasPermission, performedBy, ipAddress);

        return new UpdateReferralStatusResponse(
            referralId, status, newReferralId == 0 ? null : newReferralId, note);
    }

    public async Task<IReadOnlyList<ReferralDto>> GetByCaseAsync(int caseId)
    {
        var referrals = await referralRepository.GetByCaseAsync(caseId);
        return referrals.Select(r => r.ToDto()).ToList();
    }

    public async Task<IReadOnlyList<ReferralDto>> GetAllAsync(int top = 100)
    {
        var referrals = await referralRepository.GetAllAsync(top);
        return referrals.Select(r => r.ToDto()).ToList();
    }

    private async Task<string?> TryApplyTransitionAsync(
        int caseId, string action, string comment,
        Func<string, bool> hasPermission, int performedBy, string ipAddress)
    {
        try
        {
            var @case = await caseService.GetByIdAsync(caseId);
            await caseService.ApplyTransitionAsync(caseId,
                new ApplyTransitionRequest(action, comment, null, @case.RowVersion),
                hasPermission, performedBy, ipAddress);
            return $"Case transition '{action}' applied.";
        }
        catch (Exception ex) when (ex is NotFoundException
            or WorkflowException or ConcurrencyException or ForbiddenException)
        {
            return $"Transition not applied: {ex.Message}";
        }
    }
}
