using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface ICaseService
{
    Task<CaseDto> CreateAsync(CreateCaseRequest request, int performedBy, string ipAddress);
    Task<CaseDto> GetByIdAsync(int caseId);
    Task<CaseDto> UpdateDetailsAsync(int caseId, UpdateCaseRequest request, int performedBy, string ipAddress);
    Task AssignAsync(int caseId, AssignCaseRequest request, int performedBy, string ipAddress);
    Task<CaseDto> ApplyTransitionAsync(
        int caseId, ApplyTransitionRequest request, Func<string, bool> hasPermission,
        int performedBy, string ipAddress);
    Task<IReadOnlyList<AllowedTransitionDto>> GetAllowedTransitionsAsync(
        int caseId, Func<string, bool> hasPermission);
    Task<IReadOnlyList<CaseHistoryDto>> GetHistoryAsync(int caseId);
    Task<CaseListResponse> ListAsync(string? search, int page, int pageSize);
}
