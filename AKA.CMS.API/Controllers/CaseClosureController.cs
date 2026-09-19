using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Handles case-closure requests and supervisor approval.</summary>
[ApiController]
[Route("api/case-closures")]
[Authorize]
public sealed class CaseClosureController(
    ICaseClosureService closureService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Get by case.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<CaseClosureDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("by-case")]
    [Authorize(Policy = PermissionPolicies.CaseClosureRead)]
    public async Task<ActionResult<IReadOnlyList<CaseClosureDto>>> GetByCase(
        [FromQuery] int? caseId)
    {
        if (!caseId.HasValue) return BadRequest("caseId query parameter is required.");
        return Ok(await closureService.GetByCaseAsync(caseId.Value));
    }

    /// <summary>Request closure.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(CaseClosureDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("request")]
    [Authorize(Policy = PermissionPolicies.CaseClosureWrite)]
    public async Task<ActionResult<CaseClosureDto>> RequestClosure(
        [FromBody] RequestCaseClosureRequest request)
    {
        var created = await closureService.RequestClosureAsync(
            request, currentUser.UserId, ClientIpAddress);
        return StatusCode(StatusCodes.Status201Created, created);
    }

    /// <summary>Approve.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(ApproveCaseClosureResponse))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("{id:int}/approve")]
    [Authorize(Policy = PermissionPolicies.CaseClosureApprove)]
    public async Task<ActionResult<ApproveCaseClosureResponse>> Approve(
        int id, [FromBody] ApproveCaseClosureRequest request)
        => Ok(await closureService.ApproveClosureAsync(
            id, request, currentUser.HasPermission, currentUser.UserId, ClientIpAddress));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
