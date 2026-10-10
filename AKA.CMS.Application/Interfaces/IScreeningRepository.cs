using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IScreeningRepository
{
    Task<IReadOnlyList<ScreeningTool>> GetToolsAsync();

    Task<Screening> SubmitAsync(
        int caseId, string toolCode, string itemScoresJson,
        int performedBy, string ipAddress);

    Task<IReadOnlyList<Screening>> GetByCaseAsync(int caseId);

    Task<Screening> UpdateAsync(
        int screeningId, string itemScoresJson, byte[] rowVersion,
        int performedBy, string ipAddress);
}
