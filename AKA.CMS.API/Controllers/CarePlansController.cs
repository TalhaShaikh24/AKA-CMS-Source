using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Manages action care plans and risk-routing rules.</summary>
[ApiController]
[Route("api/care-plans")]
[Authorize]
public sealed class CarePlansController(ICarePlanService carePlanService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Get routing rules.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<RiskRoutingRuleDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("routing-rules")]
    [Authorize(Policy = PermissionPolicies.CarePlansRead)]
    public async Task<ActionResult<IReadOnlyList<RiskRoutingRuleDto>>> GetRoutingRules()
        => Ok(await carePlanService.GetRoutingRulesAsync());

    /// <summary>Create.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(ActionCarePlanDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.CarePlansWrite)]
    public async Task<ActionResult<ActionCarePlanDto>> Create([FromBody] CreateCarePlanRequest request)
    {
        var plan = await carePlanService.CreateAsync(
            request, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(
            nameof(GetByCase),
            new { caseId = plan.CaseId },
            plan);
    }

    /// <summary>Get by case.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<ActionCarePlanDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("case/{caseId:int}")]
    [Authorize(Policy = PermissionPolicies.CarePlansRead)]
    public async Task<ActionResult<IReadOnlyList<ActionCarePlanDto>>> GetByCase(int caseId)
        => Ok(await carePlanService.GetByCaseAsync(caseId));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
