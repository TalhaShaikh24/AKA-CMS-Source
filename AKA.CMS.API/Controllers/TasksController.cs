using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Tasks &amp; assignments (mobile design flow).</summary>
[ApiController]
[Route("api/tasks")]
[Authorize]
public sealed class TasksController(
    ITaskService taskService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>List tasks (tabs: All, DueToday, Overdue).</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<TaskDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.TasksRead)]
    public async Task<ActionResult<IReadOnlyList<TaskDto>>> GetAll(
        [FromQuery] string tab = "All",
        [FromQuery] int? caseId = null,
        [FromQuery] int? assignedToUserId = null)
        => Ok(await taskService.GetAllAsync(tab, caseId, assignedToUserId));

    /// <summary>Get a task by id.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(TaskDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet("{id:int}")]
    [Authorize(Policy = PermissionPolicies.TasksRead)]
    public async Task<ActionResult<TaskDto>> GetById(int id)
        => Ok(await taskService.GetByIdAsync(id));

    /// <summary>Create a task.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(TaskDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.TasksWrite)]
    public async Task<ActionResult<TaskDto>> Create([FromBody] CreateTaskRequest request)
    {
        var created = await taskService.CreateAsync(request, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(nameof(GetById), new { id = created.TaskId }, created);
    }

    /// <summary>Update a task's status.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(TaskDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status409Conflict, Type = typeof(ProblemDetails))]
    [HttpPatch("{id:int}/status")]
    [Authorize(Policy = PermissionPolicies.TasksWrite)]
    public async Task<ActionResult<TaskDto>> UpdateStatus(int id, [FromBody] UpdateTaskStatusRequest request)
        => Ok(await taskService.UpdateStatusAsync(id, request, currentUser.UserId, ClientIpAddress));

    /// <summary>Assign a task to a role/user.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(TaskDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status409Conflict, Type = typeof(ProblemDetails))]
    [HttpPost("{id:int}/assign")]
    [Authorize(Policy = PermissionPolicies.TasksWrite)]
    public async Task<ActionResult<TaskDto>> Assign(int id, [FromBody] AssignTaskRequest request)
        => Ok(await taskService.AssignAsync(id, request, currentUser.UserId, ClientIpAddress));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
