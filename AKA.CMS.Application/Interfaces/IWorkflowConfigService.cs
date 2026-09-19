using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IWorkflowConfigService
{
    Task<IReadOnlyList<WorkflowStateDto>> GetStatesAsync();
    Task<IReadOnlyList<WorkflowTransitionDto>> GetTransitionsAsync();
    Task<WorkflowTransitionDto> CreateTransitionAsync(
        CreateWorkflowTransitionRequest request, int performedBy, string ipAddress);
    Task SetTransitionActiveAsync(
        int transitionId, SetTransitionActiveRequest request, int performedBy, string ipAddress);
}
