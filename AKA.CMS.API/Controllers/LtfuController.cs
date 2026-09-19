using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Lost-to-follow-up detection and re-engagement.</summary>
[ApiController]
[Route("api/ltfu")]
[Authorize]
public sealed class LtfuController(
    ILtfuService ltfuService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Get by case.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(LostToFollowUpDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("by-case")]
    [Authorize(Policy = PermissionPolicies.FollowUpsRead)]
    public async Task<ActionResult<LostToFollowUpDto>> GetByCase(
        [FromQuery] int? caseId)
    {
        if (!caseId.HasValue) return BadRequest("caseId query parameter is required.");
        var tracking = await ltfuService.GetByCaseAsync(caseId.Value);
        return tracking is null ? NotFound() : Ok(tracking);
    }

    /// <summary>Evaluate.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(EvaluateLtfuResponse))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("cases/{caseId:int}/evaluate")]
    [Authorize(Policy = PermissionPolicies.FollowUpsWrite)]
    public async Task<ActionResult<EvaluateLtfuResponse>> Evaluate(int caseId)
        => Ok(await ltfuService.EvaluateAsync(
            caseId, currentUser.HasPermission, currentUser.UserId, ClientIpAddress));

    /// <summary>Re engage.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(ReEngageLtfuResponse))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("cases/{caseId:int}/re-engage")]
    [Authorize(Policy = PermissionPolicies.FollowUpsWrite)]
    public async Task<ActionResult<ReEngageLtfuResponse>> ReEngage(
        int caseId, [FromBody] ReEngageLtfuRequest request)
        => Ok(await ltfuService.ReEngageAsync(
            caseId, request, currentUser.HasPermission, currentUser.UserId, ClientIpAddress));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
