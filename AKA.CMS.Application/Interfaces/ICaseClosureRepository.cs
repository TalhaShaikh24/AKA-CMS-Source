using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface ICaseClosureRepository
{
    Task<int> RequestClosureAsync(
        int caseId, string closureReason, bool symptomRemission,
        string? closureSummary, int requestedByUserId,
        int createdBy, string ipAddress);
    Task<(int CaseId, byte[] CaseRowVersion)> ApproveClosureAsync(
        int closureId, bool approve, string? rejectionReason,
        int approvedByUserId, byte[] rowVersion,
        int performedBy, string ipAddress);
    Task<IReadOnlyList<CaseClosure>> GetByCaseAsync(int caseId);
}
