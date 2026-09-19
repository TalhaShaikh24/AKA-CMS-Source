using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Logs helpline calls (with automatic crisis detection).</summary>
[ApiController]
[Route("api/helpline")]
[Authorize]
public sealed class HelplineController(IHelplineService helplineService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Log call.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(LogHelplineCallResponse))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("calls")]
    [Authorize(Policy = PermissionPolicies.HelplineWrite)]
    public async Task<ActionResult<LogHelplineCallResponse>> LogCall([FromBody] LogHelplineCallRequest request)
    {
        var response = await helplineService.LogCallAsync(
            request, currentUser.HasPermission, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(
            nameof(GetCalls),
            new { caseId = response.Call.CaseId },
            response);
    }

    /// <summary>Get calls.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<HelplineCallDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("calls")]
    [Authorize(Policy = PermissionPolicies.HelplineRead)]
    public async Task<ActionResult<IReadOnlyList<HelplineCallDto>>> GetCalls(
        [FromQuery] int? caseId, [FromQuery] int top = 50)
        => Ok(await helplineService.GetCallsAsync(caseId, top));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
