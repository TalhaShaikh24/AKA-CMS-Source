using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Manages crisis events and crisis types.</summary>
[ApiController]
[Route("api/crisis-events")]
[Authorize]
public sealed class CrisisEventsController(ICrisisService crisisService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Get types.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<CrisisTypeDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("types")]
    [Authorize(Policy = PermissionPolicies.CrisisRead)]
    public async Task<ActionResult<IReadOnlyList<CrisisTypeDto>>> GetTypes()
        => Ok(await crisisService.GetTypesAsync());

    /// <summary>Trigger.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(TriggerCrisisEventResponse))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.CrisisWrite)]
    public async Task<ActionResult<TriggerCrisisEventResponse>> Trigger([FromBody] TriggerCrisisEventRequest request)
    {
        var response = await crisisService.TriggerAsync(
            request, currentUser.HasPermission, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(
            nameof(GetByCase),
            new { caseId = response.Event.CaseId },
            response);
    }

    /// <summary>Update status.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(UpdateCrisisEventStatusResponse))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPatch("{id:int}/status")]
    [Authorize(Policy = PermissionPolicies.CrisisWrite)]
    public async Task<ActionResult<UpdateCrisisEventStatusResponse>> UpdateStatus(
        int id, [FromBody] UpdateCrisisEventStatusRequest request)
    {
        var response = await crisisService.UpdateStatusAsync(
            id, request, currentUser.HasPermission, currentUser.UserId, ClientIpAddress);
        return Ok(response);
    }

    /// <summary>Get by case.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<CrisisEventDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("case/{caseId:int}")]
    [Authorize(Policy = PermissionPolicies.CrisisRead)]
    public async Task<ActionResult<IReadOnlyList<CrisisEventDto>>> GetByCase(int caseId)
        => Ok(await crisisService.GetByCaseAsync(caseId));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
