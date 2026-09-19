using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class WorkflowConfigService(
    IWorkflowConfigRepository workflowConfigRepository,
    IValidator<CreateWorkflowTransitionRequest> createValidator,
    IValidator<SetTransitionActiveRequest> setActiveValidator) : IWorkflowConfigService
{
    public async Task<IReadOnlyList<WorkflowStateDto>> GetStatesAsync()
    {
        var states = await workflowConfigRepository.GetStatesAsync();
        return states.Select(s => s.ToDto()).ToList();
    }

    public async Task<IReadOnlyList<WorkflowTransitionDto>> GetTransitionsAsync()
    {
        var transitions = await workflowConfigRepository.GetTransitionsAsync();
        return transitions.Select(t => t.ToDto()).ToList();
    }

    public async Task<WorkflowTransitionDto> CreateTransitionAsync(
        CreateWorkflowTransitionRequest request, int performedBy, string ipAddress)
    {
        await createValidator.ValidateAndThrowAsync(request);

        var transitionId = await workflowConfigRepository.CreateTransitionAsync(
            request.FromState, request.ActionCode, request.ActionName, request.ToState,
            request.RequiredPermissionName, request.SortOrder, performedBy, ipAddress);

        var transitions = await workflowConfigRepository.GetTransitionsAsync();
        return transitions.First(t => t.TransitionId == transitionId).ToDto();
    }

    public async Task SetTransitionActiveAsync(
        int transitionId, SetTransitionActiveRequest request, int performedBy, string ipAddress)
    {
        await setActiveValidator.ValidateAndThrowAsync(request);

        await workflowConfigRepository.SetTransitionActiveAsync(
            transitionId, request.IsActive, request.RowVersion, performedBy, ipAddress);
    }
}
