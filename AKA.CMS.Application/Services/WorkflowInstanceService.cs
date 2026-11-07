using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;

namespace AKA.CMS.Application.Services;

/// <summary>Workflow instances (DZ_ChildCareV3 tbl_WorkFlow_Instance /
/// _Log): one live request per form entry, travelling its workflow's
/// steps. A button press moves the instance to the next step and the
/// next role, and writes a log row — the instance row is the present,
/// the log is the past.</summary>
public sealed class WorkflowInstanceService(
    IWorkflowInstanceRepository instances,
    IWorkflowRepository workflows,
    IDynamicFormRepository forms) : IWorkflowInstanceService
{
    public async Task<WorkflowInstanceDto> StartAsync(StartWorkflowInstanceRequest request, int performedBy)
    {
        var workflow = await workflows.GetByIdAsync(request.WorkflowId)
            ?? throw new NotFoundException($"Workflow {request.WorkflowId} not found.");
        if (!workflow.IsActive)
            throw new InvalidDomainValueException("This workflow is inactive.");
        var submission = await forms.GetSubmissionByIdAsync(request.SubmissionId)
            ?? throw new NotFoundException($"Submission {request.SubmissionId} not found.");
        if (submission.FormId != workflow.FormId)
            throw new InvalidDomainValueException("This entry belongs to another form.");
        var id = await instances.StartAsync(request.WorkflowId, request.SubmissionId, request.Comments, performedBy);
        return await GetByIdAsync(id);
    }

    public async Task<WorkflowInstanceDto> GetByIdAsync(int instanceId)
        => await instances.GetByIdAsync(instanceId)
            ?? throw new NotFoundException($"Workflow instance {instanceId} not found.");

    public Task<IReadOnlyList<WorkflowInstanceDto>> GetMyTasksAsync(int userId)
        => instances.GetMyTasksAsync(userId);

    public async Task<WorkflowInstanceDto> ExecuteActionAsync(int instanceId, string actionCode, string? comments, int userId)
    {
        var instance = await GetByIdAsync(instanceId);
        // The assignment check: only the role the instance is waiting
        // on — or an admin — may press its buttons. The permission
        // (WorkflowInstances:Read) only opens the door; this check
        // decides whose task it is.
        var (isAdmin, roleIds) = await instances.GetUserAccessAsync(userId);
        if (instance.CurrentRoleID is not null && !isAdmin && !roleIds.Contains(instance.CurrentRoleID.Value))
            throw new ForbiddenException("This task is assigned to another role.");
        var updated = await instances.ExecuteActionAsync(instanceId, actionCode, comments, userId)
            ?? throw new NotFoundException($"Workflow instance {instanceId} not found.");
        return updated;
    }

    public async Task<IReadOnlyList<WorkflowInstanceLogDto>> GetLogAsync(int instanceId)
    {
        _ = await GetByIdAsync(instanceId);
        return await instances.GetLogAsync(instanceId);
    }

    public async Task<WorkflowStepActionsResponseDto> GetActionsAsync(int instanceId)
    {
        _ = await GetByIdAsync(instanceId);
        return await instances.GetActionsAsync(instanceId)
            ?? throw new NotFoundException($"Workflow instance {instanceId} not found.");
    }
}
