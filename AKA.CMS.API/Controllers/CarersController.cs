using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Manages carers engaged for a case (workflow "Engage Carers" steps).</summary>
[ApiController]
[Route("api/cases/{caseId:int}/carers")]
[Authorize]
public sealed class CarersController(ICarerService carerService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>List active carers for a case.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<CarerDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.CasesRead)]
    public async Task<ActionResult<IReadOnlyList<CarerDto>>> GetByCase(int caseId)
        => Ok(await carerService.GetByCaseAsync(caseId));

    /// <summary>Add a carer to a case.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(CarerDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.CasesWrite)]
    public async Task<ActionResult<CarerDto>> Add(int caseId, [FromBody] AddCarerRequest request)
    {
        var carer = await carerService.AddAsync(
            request with { CaseId = caseId }, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(
            nameof(GetByCase),
            new { caseId },
            carer);
    }

    /// <summary>Update a carer.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(CarerDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status409Conflict, Type = typeof(ProblemDetails))]
    [HttpPut("{carerId:int}")]
    [Authorize(Policy = PermissionPolicies.CasesWrite)]
    public async Task<ActionResult<CarerDto>> Update(
        int caseId, int carerId, [FromBody] UpdateCarerRequest request)
        => Ok(await carerService.UpdateAsync(
            carerId, caseId, request, currentUser.UserId, ClientIpAddress));

    /// <summary>Deactivate a carer (soft delete). rowVersion is base64.</summary>
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status409Conflict, Type = typeof(ProblemDetails))]
    [HttpDelete("{carerId:int}")]
    [Authorize(Policy = PermissionPolicies.CasesWrite)]
    public async Task<IActionResult> Deactivate(
        int caseId, int carerId, [FromQuery] string rowVersion)
    {
        byte[] version;
        try { version = Convert.FromBase64String(rowVersion); }
        catch (FormatException)
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Invalid value.",
                Detail = "rowVersion must be base64.",
                Status = StatusCodes.Status400BadRequest
            });
        }

        await carerService.DeactivateAsync(
            carerId, caseId, version, currentUser.UserId, ClientIpAddress);
        return NoContent();
    }

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
