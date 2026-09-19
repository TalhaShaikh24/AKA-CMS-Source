using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Generic master-data lookup endpoint.</summary>
[ApiController]
[Route("api/lookups")]
[Authorize]
public sealed class LookupsController(ILookupService lookupService) : ControllerBase
{
    /// <summary>Get by type.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<LookupItemDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("{type}")]
    [Authorize(Policy = PermissionPolicies.LookupsRead)]
    public async Task<ActionResult<IReadOnlyList<LookupItemDto>>> GetByType(string type)
        => Ok(await lookupService.GetByTypeAsync(type));
}
