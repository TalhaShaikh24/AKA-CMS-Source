using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IScreeningService
{
    Task<IReadOnlyList<ScreeningToolDto>> GetToolsAsync();

    Task<SubmitScreeningResponse> SubmitAsync(
        SubmitScreeningRequest request, Func<string, bool> hasPermission,
        int performedBy, string ipAddress);

    Task<IReadOnlyList<ScreeningDto>> GetByCaseAsync(int caseId);

    Task<ScreeningDto> UpdateAsync(
        int screeningId, UpdateScreeningRequest request,
        Func<string, bool> hasPermission, int performedBy, string ipAddress);
}
