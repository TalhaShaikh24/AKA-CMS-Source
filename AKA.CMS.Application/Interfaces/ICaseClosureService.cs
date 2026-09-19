using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface ICaseClosureService
{
    Task<CaseClosureDto> RequestClosureAsync(
        RequestCaseClosureRequest request, int performedBy, string ipAddress);
    Task<ApproveCaseClosureResponse> ApproveClosureAsync(
        int closureId, ApproveCaseClosureRequest request,
        Func<string, bool> hasPermission, int performedBy, string ipAddress);
    Task<IReadOnlyList<CaseClosureDto>> GetByCaseAsync(int caseId);
}
