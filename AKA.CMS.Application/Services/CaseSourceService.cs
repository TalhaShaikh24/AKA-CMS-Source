using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class CaseSourceService(
    ICaseSourceRepository caseSourceRepository,
    IValidator<RecordCaseSourceRequest> recordValidator) : ICaseSourceService
{
    public async Task<CaseSourceMappingDto> RecordAsync(
        int caseId, RecordCaseSourceRequest request, int performedBy, string ipAddress)
    {
        await recordValidator.ValidateAndThrowAsync(request);

        await caseSourceRepository.RecordAsync(
            caseId, request.SourceType, request.SourceReferenceId, performedBy, ipAddress);

        var mapping = await caseSourceRepository.GetByCaseAsync(caseId)
            ?? throw new NotFoundException($"Case source for case {caseId} not found.");
        return mapping.ToDto();
    }

    public async Task<CaseSourceMappingDto?> GetByCaseAsync(int caseId)
    {
        var mapping = await caseSourceRepository.GetByCaseAsync(caseId);
        return mapping?.ToDto();
    }

    public async Task<IReadOnlyList<CaseSourceTypeDto>> GetTypesAsync()
    {
        var types = await caseSourceRepository.GetTypesAsync();
        return types.Select(t => t.ToDto()).ToList();
    }
}
