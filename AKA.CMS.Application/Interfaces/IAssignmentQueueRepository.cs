using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IAssignmentQueueRepository
{
    Task<int> EnqueueAsync(int caseId, string riskCategory, int enqueuedBy, string ipAddress);
    Task AssignAsync(int queueId, int assignedToUserId, byte[] rowVersion, int performedBy, string ipAddress);
    Task<IReadOnlyList<CaseAssignmentQueueEntry>> GetPendingAsync();
}
