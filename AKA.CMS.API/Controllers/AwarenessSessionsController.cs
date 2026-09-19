using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Manages community awareness sessions and participants.</summary>
[ApiController]
[Route("api/awareness-sessions")]
[Authorize]
public sealed class AwarenessSessionsController(
    IAwarenessSessionService sessionService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Create.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(AwarenessSessionDetailDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.AwarenessSessionsWrite)]
    public async Task<ActionResult<AwarenessSessionDetailDto>> Create(
        [FromBody] CreateAwarenessSessionRequest request)
    {
        var created = await sessionService.CreateAsync(request, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(nameof(GetById), new { id = created.Session.SessionId }, created);
    }

    /// <summary>Get list.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<AwarenessSessionDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.AwarenessSessionsRead)]
    public async Task<ActionResult<IReadOnlyList<AwarenessSessionDto>>> GetList(
        [FromQuery] string? facilityCode, [FromQuery] DateTime? fromDate,
        [FromQuery] DateTime? toDate, [FromQuery] int top = 50)
        => Ok(await sessionService.GetListAsync(facilityCode, fromDate, toDate, top));

    /// <summary>Get by id.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(AwarenessSessionDetailDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet("{id:int}")]
    [Authorize(Policy = PermissionPolicies.AwarenessSessionsRead)]
    public async Task<ActionResult<AwarenessSessionDetailDto>> GetById(int id)
        => Ok(await sessionService.GetByIdAsync(id));

    /// <summary>Update.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(AwarenessSessionDetailDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPatch("{id:int}")]
    [Authorize(Policy = PermissionPolicies.AwarenessSessionsWrite)]
    public async Task<ActionResult<AwarenessSessionDetailDto>> Update(
        int id, [FromBody] UpdateAwarenessSessionRequest request)
        => Ok(await sessionService.UpdateAsync(id, request, currentUser.UserId, ClientIpAddress));

    /// <summary>Register participant.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(RegisterSessionParticipantResponse))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("{id:int}/participants")]
    [Authorize(Policy = PermissionPolicies.AwarenessSessionsWrite)]
    public async Task<ActionResult<RegisterSessionParticipantResponse>> RegisterParticipant(
        int id, [FromBody] RegisterSessionParticipantRequest request)
    {
        var response = await sessionService.RegisterParticipantAsync(
            id, request, currentUser.UserId, ClientIpAddress);
        return response.WasNew
            ? CreatedAtAction(nameof(GetById), new { id }, response)
            : Ok(response);
    }

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
