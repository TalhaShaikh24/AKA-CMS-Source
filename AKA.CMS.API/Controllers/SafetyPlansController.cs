using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Creates and reads safety plans for crisis cases.</summary>
[ApiController]
[Route("api/safety-plans")]
[Authorize]
public sealed class SafetyPlansController(ISafetyPlanService safetyPlanService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Create.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(SafetyPlanDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.SafetyPlansWrite)]
    public async Task<ActionResult<SafetyPlanDto>> Create([FromBody] CreateSafetyPlanRequest request)
    {
        var plan = await safetyPlanService.CreateAsync(request, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(
            nameof(GetByCase),
            new { caseId = plan.CaseId },
            plan);
    }

    /// <summary>Get by case.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<SafetyPlanDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("case/{caseId:int}")]
    [Authorize(Policy = PermissionPolicies.SafetyPlansRead)]
    public async Task<ActionResult<IReadOnlyList<SafetyPlanDto>>> GetByCase(int caseId)
        => Ok(await safetyPlanService.GetByCaseAsync(caseId));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
