using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Workflow instances: one live request per form entry,
/// travelling its workflow's steps. Starting and pressing a button
/// are gated by WorkflowInstances:Read plus the assignment check in
/// the service (the instance's current role must be one of the
/// user's roles, or the user is admin) — a frontline user can act
/// on their own task without the Write permission.</summary>
[ApiController]
[Route("api/workflow-instances")]
[Authorize]
public sealed class WorkflowInstancesController(IWorkflowInstanceService service, ICurrentUser currentUser) : ControllerBase
{
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.WorkflowInstancesRead)]
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(WorkflowInstanceDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowInstanceDto>> Start([FromBody] StartWorkflowInstanceRequest request)
    {
        var created = await service.StartAsync(request, currentUser.UserId);
        return CreatedAtAction(nameof(GetById), new { id = created.WorkflowInstanceId }, created);
    }

    /// <summary>Attach the entry created after an instance-first start
    /// (2026-11-10) to its request. The request must not have an entry
    /// yet and the entry must belong to the workflow's form.</summary>
    [HttpPost("{id:int}/link-submission")]
    [Authorize(Policy = PermissionPolicies.WorkflowInstancesRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(WorkflowInstanceDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowInstanceDto>> LinkSubmission(int id, [FromBody] LinkWorkflowSubmissionRequest request)
        => Ok(await service.LinkSubmissionAsync(id, request.SubmissionId));

    [HttpGet("my-tasks")]
    [Authorize(Policy = PermissionPolicies.WorkflowInstancesRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<WorkflowInstanceDto>))]
    public async Task<ActionResult<IReadOnlyList<WorkflowInstanceDto>>> GetMyTasks()
        => Ok(await service.GetMyTasksAsync(currentUser.UserId));

    /// <summary>Requests the user started themselves (CreatedBy =
    /// the user). Finished instances are included — a request stays
    /// visible after it completes.</summary>
    [HttpGet("my-requests")]
    [Authorize(Policy = PermissionPolicies.WorkflowInstancesRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<WorkflowInstanceDto>))]
    public async Task<ActionResult<IReadOnlyList<WorkflowInstanceDto>>> GetMyRequests()
        => Ok(await service.GetMyRequestsAsync(currentUser.UserId));

    [HttpGet("{id:int}")]
    [Authorize(Policy = PermissionPolicies.WorkflowInstancesRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(WorkflowInstanceDto))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowInstanceDto>> GetById(int id)
        => Ok(await service.GetByIdAsync(id));

    /// <summary>The buttons under the form at the instance's current
    /// step, with the step they belong to.</summary>
    [HttpGet("{id:int}/actions")]
    [Authorize(Policy = PermissionPolicies.WorkflowInstancesRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(WorkflowStepActionsResponseDto))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowStepActionsResponseDto>> GetActions(int id)
        => Ok(await service.GetActionsAsync(id));

    /// <summary>Press a button: the form data must already be saved
    /// (the render page saves the entry first), this only moves the
    /// instance to the button's next step and next role, and logs it.</summary>
    [HttpPost("{id:int}/actions/{actionCode}")]
    [Authorize(Policy = PermissionPolicies.WorkflowInstancesRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(WorkflowInstanceDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowInstanceDto>> ExecuteAction(
        int id, string actionCode, [FromBody] ExecuteWorkflowActionRequest? request)
        => Ok(await service.ExecuteActionAsync(id, actionCode, request?.Comments, currentUser.UserId));

    [HttpGet("{id:int}/log")]
    [Authorize(Policy = PermissionPolicies.WorkflowInstancesRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<WorkflowInstanceLogDto>))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<IReadOnlyList<WorkflowInstanceLogDto>>> GetLog(int id)
        => Ok(await service.GetLogAsync(id));
}
