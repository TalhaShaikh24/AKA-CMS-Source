using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Manages the case-assignment queue (routing and assignment).</summary>
[ApiController]
[Route("api/assignment-queue")]
[Authorize]
public sealed class AssignmentQueueController(IAssignmentService assignmentService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Route.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(RouteCaseResponse))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("route")]
    [Authorize(Policy = PermissionPolicies.AssignmentQueueWrite)]
    public async Task<ActionResult<RouteCaseResponse>> Route([FromBody] RouteCaseRequest request)
        => Ok(await assignmentService.RouteCaseAsync(
            request, currentUser.HasPermission,
            currentUser.UserId, ClientIpAddress));

    /// <summary>Assign.</summary>
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status409Conflict, Type = typeof(ProblemDetails))]
    [HttpPost("{queueId:int}/assign")]
    [Authorize(Policy = PermissionPolicies.AssignmentQueueWrite)]
    public async Task<IActionResult> Assign(int queueId, [FromBody] AssignQueueRequest request)
    {
        await assignmentService.AssignAsync(
            queueId, request, currentUser.UserId, ClientIpAddress);
        return NoContent();
    }

    /// <summary>Get pending.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<QueueEntryDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("pending")]
    [Authorize(Policy = PermissionPolicies.AssignmentQueueRead)]
    public async Task<ActionResult<IReadOnlyList<QueueEntryDto>>> GetPending()
        => Ok(await assignmentService.GetPendingAsync());

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
