using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface ICaseSourceService
{
    Task<CaseSourceMappingDto> RecordAsync(
        int caseId, RecordCaseSourceRequest request, int performedBy, string ipAddress);
    Task<CaseSourceMappingDto?> GetByCaseAsync(int caseId);
    Task<IReadOnlyList<CaseSourceTypeDto>> GetTypesAsync();
}
