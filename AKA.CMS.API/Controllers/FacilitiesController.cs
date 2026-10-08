using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Facility directory (program sites).</summary>
[ApiController]
[Route("api/facilities")]
[Authorize]
public sealed class FacilitiesController(
    IFacilityService facilityService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>List facilities.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<FacilityDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.FacilitiesRead)]
    public async Task<ActionResult<IReadOnlyList<FacilityDto>>> GetAll(
        [FromQuery] bool includeInactive = false)
        => Ok(await facilityService.GetAllAsync(includeInactive));

    /// <summary>Get a facility by id.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(FacilityDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet("{id:int}")]
    [Authorize(Policy = PermissionPolicies.FacilitiesRead)]
    public async Task<ActionResult<FacilityDto>> GetById(int id)
        => Ok(await facilityService.GetByIdAsync(id));

    /// <summary>Create a facility.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(FacilityDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status409Conflict, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.FacilitiesWrite)]
    public async Task<ActionResult<FacilityDto>> Create([FromBody] CreateFacilityRequest request)
    {
        var created = await facilityService.CreateAsync(request, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(nameof(GetById), new { id = created.FacilityId }, created);
    }

    /// <summary>Update a facility.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(FacilityDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status409Conflict, Type = typeof(ProblemDetails))]
    [HttpPut("{id:int}")]
    [Authorize(Policy = PermissionPolicies.FacilitiesWrite)]
    public async Task<ActionResult<FacilityDto>> Update(int id, [FromBody] UpdateFacilityRequest request)
        => Ok(await facilityService.UpdateAsync(id, request, currentUser.UserId, ClientIpAddress));

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
