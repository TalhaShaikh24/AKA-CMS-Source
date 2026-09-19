using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IAssignmentService
{
    /// <summary>
    /// Implements the High/Moderate/Low risk branch logic (workflow S18-S25):
    /// creates the action care plan, enqueues the assignment with the
    /// rule's SLA, creates referrals per the rule's targets and adds an
    /// alert comment when the rule requires supervisor attention.
    /// </summary>
    Task<RouteCaseResponse> RouteCaseAsync(
        RouteCaseRequest request, Func<string, bool> hasPermission,
        int performedBy, string ipAddress);
    Task AssignAsync(int queueId, AssignQueueRequest request, int performedBy, string ipAddress);
    Task<IReadOnlyList<QueueEntryDto>> GetPendingAsync();
}
