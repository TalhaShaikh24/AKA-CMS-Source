using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Reads the permission catalog.</summary>
[ApiController]
[Route("api/permissions")]
[Authorize]
public sealed class PermissionsController(IPermissionService permissionService) : ControllerBase
{
    /// <summary>Get catalog.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<PermissionDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.PermissionsRead)]
    public async Task<ActionResult<IReadOnlyList<PermissionDto>>> GetCatalog()
        => Ok(await permissionService.GetCatalogAsync());
}
