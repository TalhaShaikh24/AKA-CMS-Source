using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Admin configuration of workflow states and transitions.</summary>
[ApiController]
[Route("api/workflow")]
[Authorize]
public sealed class WorkflowConfigController(
    IWorkflowConfigService workflowConfigService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Get states.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<WorkflowStateDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("states")]
    [Authorize(Policy = PermissionPolicies.WorkflowConfigRead)]
    public async Task<ActionResult<IReadOnlyList<WorkflowStateDto>>> GetStates()
        => Ok(await workflowConfigService.GetStatesAsync());

    /// <summary>Get transitions.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<WorkflowTransitionDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("transitions")]
    [Authorize(Policy = PermissionPolicies.WorkflowConfigRead)]
    public async Task<ActionResult<IReadOnlyList<WorkflowTransitionDto>>> GetTransitions()
        => Ok(await workflowConfigService.GetTransitionsAsync());

    /// <summary>Create transition.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(WorkflowTransitionDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("transitions")]
    [Authorize(Policy = PermissionPolicies.WorkflowConfigWrite)]
    public async Task<ActionResult<WorkflowTransitionDto>> CreateTransition(
        [FromBody] CreateWorkflowTransitionRequest request)
    {
        var created = await workflowConfigService.CreateTransitionAsync(
            request, currentUser.UserId, ClientIpAddress);
        return StatusCode(StatusCodes.Status201Created, created);
    }

    /// <summary>Set transition active.</summary>
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPatch("transitions/{id:int}")]
    [Authorize(Policy = PermissionPolicies.WorkflowConfigWrite)]
    public async Task<IActionResult> SetTransitionActive(
        int id, [FromBody] SetTransitionActiveRequest request)
    {
        await workflowConfigService.SetTransitionActiveAsync(
            id, request, currentUser.UserId, ClientIpAddress);
        return NoContent();
    }

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
