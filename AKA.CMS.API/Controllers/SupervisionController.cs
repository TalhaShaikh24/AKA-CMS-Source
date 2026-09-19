using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Logs clinical supervision sessions.</summary>
[ApiController]
[Route("api/supervision")]
[Authorize]
public sealed class SupervisionController(
    ISupervisionService supervisionService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Get by case.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<SupervisionLogDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("logs/by-case")]
    [Authorize(Policy = PermissionPolicies.SupervisionRead)]
    public async Task<ActionResult<IReadOnlyList<SupervisionLogDto>>> GetByCase(
        [FromQuery] int? caseId)
    {
        if (!caseId.HasValue) return BadRequest("caseId query parameter is required.");
        return Ok(await supervisionService.GetByCaseAsync(caseId.Value));
    }

    /// <summary>Log review.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(SupervisionLogDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("logs")]
    [Authorize(Policy = PermissionPolicies.SupervisionWrite)]
    public async Task<ActionResult<SupervisionLogDto>> LogReview(
        [FromBody] LogSupervisionRequest request)
    {
        var created = await supervisionService.LogReviewAsync(
            request, currentUser.UserId, ClientIpAddress);
        return StatusCode(StatusCodes.Status201Created, created);
    }

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
