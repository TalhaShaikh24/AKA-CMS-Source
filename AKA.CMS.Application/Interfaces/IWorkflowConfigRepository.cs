using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IWorkflowConfigRepository
{
    Task<IReadOnlyList<WorkflowState>> GetStatesAsync();
    Task<IReadOnlyList<WorkflowTransition>> GetTransitionsAsync();
    Task<int> CreateTransitionAsync(
        string fromState, string actionCode, string actionName, string toState,
        string? requiredPermissionName, int sortOrder, int performedBy, string ipAddress);
    Task SetTransitionActiveAsync(
        int transitionId, bool isActive, byte[] rowVersion, int performedBy, string ipAddress);
}
