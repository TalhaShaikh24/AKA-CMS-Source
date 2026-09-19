using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Manages psychological and pharmacological treatment plans.</summary>
[ApiController]
[Route("api/treatment-plans")]
[Authorize]
public sealed class TreatmentPlansController(
    ITreatmentPlanService planService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Create.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(TreatmentPlanDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.TreatmentPlansWrite)]
    public async Task<ActionResult<TreatmentPlanDto>> Create(
        [FromBody] CreateTreatmentPlanRequest request)
    {
        var created = await planService.CreateAsync(request, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(nameof(GetById), new { id = created.PlanId }, created);
    }

    /// <summary>Get list.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<TreatmentPlanDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.TreatmentPlansRead)]
    public async Task<ActionResult<IReadOnlyList<TreatmentPlanDto>>> GetList(
        [FromQuery] int? caseId)
    {
        if (!caseId.HasValue) return BadRequest("caseId query parameter is required.");
        return Ok(await planService.GetByCaseAsync(caseId.Value));
    }

    /// <summary>Get by id.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(TreatmentPlanDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet("{id:int}")]
    [Authorize(Policy = PermissionPolicies.TreatmentPlansRead)]
    public async Task<ActionResult<TreatmentPlanDto>> GetById(int id)
        => Ok(await planService.GetByIdAsync(id));

    /// <summary>Update.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(TreatmentPlanDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPatch("{id:int}")]
    [Authorize(Policy = PermissionPolicies.TreatmentPlansWrite)]
    public async Task<ActionResult<TreatmentPlanDto>> Update(
        int id, [FromBody] UpdateTreatmentPlanRequest request)
        => Ok(await planService.UpdateAsync(id, request, currentUser.UserId, ClientIpAddress));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
