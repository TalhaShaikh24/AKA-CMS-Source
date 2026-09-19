using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface ISupervisionService
{
    Task<SupervisionLogDto> LogReviewAsync(
        LogSupervisionRequest request, int performedBy, string ipAddress);
    Task<IReadOnlyList<SupervisionLogDto>> GetByCaseAsync(int caseId);
}
