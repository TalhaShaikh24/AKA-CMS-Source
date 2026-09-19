using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface ICaseRepository
{
    Task<int> CreateAsync(
        int communityMemberId, string sourceType, string? priorityLevel, string? notes,
        int performedBy, string ipAddress);

    Task<Case?> GetByIdAsync(int caseId);

    Task<Case> UpdateDetailsAsync(
        int caseId, string? priorityLevel, string? notes, byte[] rowVersion,
        int performedBy, string ipAddress);

    Task AssignAsync(
        int caseId, int userId, byte[] rowVersion, int performedBy, string ipAddress);

    Task<Case> ApplyTransitionAsync(
        int caseId, string actionCode, string? comment, int? assignedToUserId,
        byte[] rowVersion, bool hasPermission, int performedBy, string ipAddress);

    Task<IReadOnlyList<WorkflowTransition>> GetAllowedTransitionsAsync(int caseId);

    Task<IReadOnlyList<CaseHistory>> GetHistoryAsync(int caseId);
}
