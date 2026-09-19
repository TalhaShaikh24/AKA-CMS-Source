using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class CaseService(
    ICaseRepository caseRepository,
    ICaseSourceRepository caseSourceRepository,
    IValidator<CreateCaseRequest> createValidator,
    IValidator<UpdateCaseRequest> updateValidator,
    IValidator<ApplyTransitionRequest> transitionValidator,
    IValidator<AssignCaseRequest> assignValidator) : ICaseService
{
    public async Task<CaseDto> CreateAsync(CreateCaseRequest request, int performedBy, string ipAddress)
    {
        await createValidator.ValidateAndThrowAsync(request);

        var caseId = await caseRepository.CreateAsync(
            request.CommunityMemberId, request.SourceType, request.PriorityLevel, request.Notes,
            performedBy, ipAddress);

        // Record the case's identification source (Phase 3: case is
        // "Linked to session"). Best-effort: the case is already
        // registered; a source-recording failure must not roll back
        // case creation.
        try
        {
            await caseSourceRepository.RecordAsync(
                caseId, request.SourceType, request.SourceReferenceId, performedBy, ipAddress);
        }
        catch (Exception ex) when (ex is InvalidDomainValueException or ConflictException)
        {
            _ = ex; // source recording is best-effort; case creation already succeeded
        }

        return await GetByIdAsync(caseId);
    }

    public async Task<CaseDto> GetByIdAsync(int caseId)
    {
        var @case = await caseRepository.GetByIdAsync(caseId)
            ?? throw new NotFoundException($"Case {caseId} not found.");
        return @case.ToDto();
    }

    public async Task<CaseDto> UpdateDetailsAsync(
        int caseId, UpdateCaseRequest request, int performedBy, string ipAddress)
    {
        await updateValidator.ValidateAndThrowAsync(request);

        var updated = await caseRepository.UpdateDetailsAsync(
            caseId, request.PriorityLevel, request.Notes, request.RowVersion, performedBy, ipAddress);
        return updated.ToDto();
    }

    public async Task AssignAsync(
        int caseId, AssignCaseRequest request, int performedBy, string ipAddress)
    {
        await assignValidator.ValidateAndThrowAsync(request);
        await caseRepository.AssignAsync(caseId, request.UserId, request.RowVersion, performedBy, ipAddress);
    }

    public async Task<CaseDto> ApplyTransitionAsync(
        int caseId, ApplyTransitionRequest request, Func<string, bool> hasPermission,
        int performedBy, string ipAddress)
    {
        await transitionValidator.ValidateAndThrowAsync(request);

        var allowed = await caseRepository.GetAllowedTransitionsAsync(caseId);
        var target = allowed.FirstOrDefault(t =>
            t.ActionCode.Equals(request.Action, StringComparison.OrdinalIgnoreCase))
            ?? throw new WorkflowException(
                $"Action '{request.Action}' is not available for this case.");

        if (string.IsNullOrWhiteSpace(target.RequiredPermissionName))
            throw new WorkflowException(
                $"Action '{request.Action}' has no required permission configured.");

        var canPerform = hasPermission(target.RequiredPermissionName);

        var updated = await caseRepository.ApplyTransitionAsync(
            caseId, target.ActionCode, request.Comment, request.AssignedToUserId,
            request.RowVersion, canPerform, performedBy, ipAddress);
        return updated.ToDto();
    }

    public async Task<IReadOnlyList<AllowedTransitionDto>> GetAllowedTransitionsAsync(
        int caseId, Func<string, bool> hasPermission)
    {
        var allowed = await caseRepository.GetAllowedTransitionsAsync(caseId);
        return allowed
            .Select(t => t.ToDto(hasPermission(t.RequiredPermissionName)))
            .ToList();
    }

    public async Task<IReadOnlyList<CaseHistoryDto>> GetHistoryAsync(int caseId)
    {
        var history = await caseRepository.GetHistoryAsync(caseId);
        return history.Select(h => h.ToDto()).ToList();
    }
}
