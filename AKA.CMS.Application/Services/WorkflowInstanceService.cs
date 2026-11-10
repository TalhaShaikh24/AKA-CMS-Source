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
        // Instance-first start (2026-11-10): no entry yet — the
        // submission is attached later via LinkSubmissionAsync.
        if (request.SubmissionId.HasValue)
        {
            var submission = await forms.GetSubmissionByIdAsync(request.SubmissionId.Value)
                ?? throw new NotFoundException($"Submission {request.SubmissionId} not found.");
            if (submission.FormId != workflow.FormId)
                throw new InvalidDomainValueException("This entry belongs to another form.");
        }
        var id = await instances.StartAsync(request.WorkflowId, request.SubmissionId, request.Comments, performedBy);
        return await GetByIdAsync(id);
    }

    public async Task<WorkflowInstanceDto> StartByCodeAsync(string code, int performedBy)
    {
        // Reusable start for module buttons (2026-11-10): the button only
        // knows the workflow code (e.g. TEST2). The workflow's form comes
        // from the workflow itself; the instance starts with no entry.
        // No new SP: the workflow list is a handful of rows.
        var workflow = (await workflows.GetAllAsync())
            .FirstOrDefault(w => string.Equals(w.WorkflowCode, code, StringComparison.OrdinalIgnoreCase) && w.IsActive)
            ?? throw new NotFoundException($"Workflow '{code}' not found or inactive.");
        var id = await instances.StartAsync(workflow.WorkflowId, null, null, performedBy);
        return await GetByIdAsync(id);
    }

    public async Task<WorkflowInstanceDto> LinkSubmissionAsync(int instanceId, int submissionId)
    {
        // 404 first, so a bad id reads as not-found; the SP then
        // validates the entry (no entry yet, right form, no other
        // request) and THROWs 50000 -> 400.
        await GetByIdAsync(instanceId);
        var linked = await instances.LinkSubmissionAsync(instanceId, submissionId)
            ?? throw new NotFoundException($"Workflow instance {instanceId} not found.");
        return linked;
    }

    public async Task<WorkflowInstanceDto> GetByIdAsync(int instanceId)
        => await instances.GetByIdAsync(instanceId)
            ?? throw new NotFoundException($"Workflow instance {instanceId} not found.");

    public Task<IReadOnlyList<WorkflowInstanceDto>> GetMyTasksAsync(int userId)
        => instances.GetMyTasksAsync(userId);

    public Task<IReadOnlyList<WorkflowInstanceDto>> GetMyRequestsAsync(int userId)
        => instances.GetMyRequestsAsync(userId);

    public async Task<WorkflowInstanceDto> ExecuteActionAsync(int instanceId, string actionCode, string? comments, int userId)
    {
        var instance = await GetByIdAsync(instanceId);
        // A comment is required on every step, always: the history log
        // must say why the action was taken. Enforced here so no client
        // (web, mobile, direct API) can move a request silently.
        if (string.IsNullOrWhiteSpace(comments))
            throw new InvalidDomainValueException("A comment is required to perform this action.");
        // The assignment check: only a role the instance is waiting
        // on — user role OR workflow role — or an admin may press its
        // buttons. A workflow role is optional: if the instance waits
        // on neither role, anyone with Read may act (as before). The
        // permission (WorkflowInstances:Read) only opens the door;
        // this check decides whose task it is.
        var (isAdmin, roleIds, workflowRoleIds) = await instances.GetUserAccessAsync(userId);
        if (!isAdmin)
        {
            var roleMatch = instance.CurrentRoleID is not null && roleIds.Contains(instance.CurrentRoleID.Value);
            var workflowRoleMatch = instance.CurrentWorkflowRoleID is not null
                && workflowRoleIds.Contains(instance.CurrentWorkflowRoleID.Value);
            var anyRoleSet = instance.CurrentRoleID is not null || instance.CurrentWorkflowRoleID is not null;
            if (anyRoleSet && !roleMatch && !workflowRoleMatch)
                throw new ForbiddenException("This task is assigned to another role.");
        }
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
