using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Records PHQ-9 / GAD-7 screenings with risk stratification.</summary>
[ApiController]
[Route("api/screenings")]
[Authorize]
public sealed class ScreeningsController(IScreeningService screeningService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Get tools.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<ScreeningToolDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("tools")]
    [Authorize(Policy = PermissionPolicies.ScreeningsRead)]
    public async Task<ActionResult<IReadOnlyList<ScreeningToolDto>>> GetTools()
        => Ok(await screeningService.GetToolsAsync());

    /// <summary>Submit.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(SubmitScreeningResponse))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("submit")]
    [Authorize(Policy = PermissionPolicies.ScreeningsWrite)]
    public async Task<ActionResult<SubmitScreeningResponse>> Submit([FromBody] SubmitScreeningRequest request)
    {
        var response = await screeningService.SubmitAsync(
            request, currentUser.HasPermission, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(
            nameof(GetByCase),
            new { caseId = response.Screening.CaseId },
            response);
    }

    /// <summary>Get by case.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<ScreeningDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("case/{caseId:int}")]
    [Authorize(Policy = PermissionPolicies.ScreeningsRead)]
    public async Task<ActionResult<IReadOnlyList<ScreeningDto>>> GetByCase(int caseId)
        => Ok(await screeningService.GetByCaseAsync(caseId));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
