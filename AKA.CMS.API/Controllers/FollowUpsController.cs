using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Schedules follow-ups and records their outcomes.</summary>
[ApiController]
[Route("api/follow-ups")]
[Authorize]
public sealed class FollowUpsController(
    IFollowUpService followUpService, IFollowUpDueService followUpDueService,
    ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Get by case.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<FollowUpDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("by-case")]
    [Authorize(Policy = PermissionPolicies.FollowUpsRead)]
    public async Task<ActionResult<IReadOnlyList<FollowUpDto>>> GetByCase(
        [FromQuery] int? caseId)
    {
        if (!caseId.HasValue) return BadRequest("caseId query parameter is required.");
        return Ok(await followUpService.GetByCaseAsync(caseId.Value));
    }

    /// <summary>Get due.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<DueFollowUpDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("due")]
    [Authorize(Policy = PermissionPolicies.FollowUpsRead)]
    public async Task<ActionResult<IReadOnlyList<DueFollowUpDto>>> GetDue()
        => Ok(await followUpDueService.GetDueAsync());

    /// <summary>Schedule.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(ScheduleFollowUpResponse))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("schedule")]
    [Authorize(Policy = PermissionPolicies.FollowUpsWrite)]
    public async Task<ActionResult<ScheduleFollowUpResponse>> Schedule(
        [FromBody] ScheduleFollowUpRequest request)
    {
        var result = await followUpService.ScheduleAsync(
            request, currentUser.HasPermission, currentUser.UserId, ClientIpAddress);
        return StatusCode(StatusCodes.Status201Created, result);
    }

    /// <summary>Record outcome.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(RecordFollowUpOutcomeResponse))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("{id:int}/outcome")]
    [Authorize(Policy = PermissionPolicies.FollowUpsWrite)]
    public async Task<ActionResult<RecordFollowUpOutcomeResponse>> RecordOutcome(
        int id, [FromBody] RecordFollowUpOutcomeRequest request)
        => Ok(await followUpService.RecordOutcomeAsync(
            id, request, currentUser.HasPermission, currentUser.UserId, ClientIpAddress));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
