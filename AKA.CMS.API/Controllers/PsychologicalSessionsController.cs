using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Logs psychological-therapy sessions.</summary>
[ApiController]
[Route("api/psychological-sessions")]
[Authorize]
public sealed class PsychologicalSessionsController(
    IPsychologicalSessionService sessionService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Record.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(PsychologicalSessionDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.PsychologicalSessionsWrite)]
    public async Task<ActionResult<PsychologicalSessionDto>> Record(
        [FromBody] RecordPsychologicalSessionRequest request)
    {
        var recorded = await sessionService.RecordAsync(request, currentUser.UserId, ClientIpAddress);
        return StatusCode(StatusCodes.Status201Created, recorded);
    }

    /// <summary>Get by case.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<PsychologicalSessionDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.PsychologicalSessionsRead)]
    public async Task<ActionResult<IReadOnlyList<PsychologicalSessionDto>>> GetByCase(
        [FromQuery] int? caseId)
    {
        if (!caseId.HasValue) return BadRequest("caseId query parameter is required.");
        return Ok(await sessionService.GetByCaseAsync(caseId.Value));
    }

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
