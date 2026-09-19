using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface ISupervisionRepository
{
    Task<int> LogReviewAsync(
        int caseId, int supervisorUserId, DateTime reviewDate,
        string findings, string? actionItems, string? rating,
        int createdBy, string ipAddress);
    Task<IReadOnlyList<SupervisionLog>> GetByCaseAsync(int caseId);
}
