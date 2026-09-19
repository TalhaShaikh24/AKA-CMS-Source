using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Registers cases, manages details, applies workflow transitions.</summary>
[ApiController]
[Route("api/cases")]
[Authorize]
public sealed class CasesController(ICaseService caseService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Create.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(CaseDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.CasesWrite)]
    public async Task<ActionResult<CaseDto>> Create([FromBody] CreateCaseRequest request)
    {
        var created = await caseService.CreateAsync(request, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(nameof(GetById), new { id = created.CaseId }, created);
    }

    /// <summary>Get by id.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(CaseDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet("{id:int}")]
    [Authorize(Policy = PermissionPolicies.CasesRead)]
    public async Task<ActionResult<CaseDto>> GetById(int id)
        => Ok(await caseService.GetByIdAsync(id));

    /// <summary>Update details.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(CaseDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status409Conflict, Type = typeof(ProblemDetails))]
    [HttpPut("{id:int}")]
    [Authorize(Policy = PermissionPolicies.CasesWrite)]
    public async Task<ActionResult<CaseDto>> UpdateDetails(int id, [FromBody] UpdateCaseRequest request)
        => Ok(await caseService.UpdateDetailsAsync(id, request, currentUser.UserId, ClientIpAddress));

    /// <summary>Apply transition.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(CaseDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status409Conflict, Type = typeof(ProblemDetails))]
    [HttpPost("{id:int}/transitions")]
    [Authorize(Policy = PermissionPolicies.CasesWrite)]
    public async Task<ActionResult<CaseDto>> ApplyTransition(int id, [FromBody] ApplyTransitionRequest request)
        => Ok(await caseService.ApplyTransitionAsync(
            id, request, currentUser.HasPermission, currentUser.UserId, ClientIpAddress));

    /// <summary>Assign.</summary>
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status409Conflict, Type = typeof(ProblemDetails))]
    [HttpPost("{id:int}/assign")]
    [Authorize(Policy = PermissionPolicies.CasesWrite)]
    public async Task<IActionResult> Assign(int id, [FromBody] AssignCaseRequest request)
    {
        await caseService.AssignAsync(id, request, currentUser.UserId, ClientIpAddress);
        return NoContent();
    }

    /// <summary>Get allowed transitions.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<AllowedTransitionDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet("{id:int}/allowed-transitions")]
    [Authorize(Policy = PermissionPolicies.CasesRead)]
    public async Task<ActionResult<IReadOnlyList<AllowedTransitionDto>>> GetAllowedTransitions(int id)
        => Ok(await caseService.GetAllowedTransitionsAsync(id, currentUser.HasPermission));

    /// <summary>Get history.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<CaseHistoryDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet("{id:int}/history")]
    [Authorize(Policy = PermissionPolicies.CasesRead)]
    public async Task<ActionResult<IReadOnlyList<CaseHistoryDto>>> GetHistory(int id)
        => Ok(await caseService.GetHistoryAsync(id));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
