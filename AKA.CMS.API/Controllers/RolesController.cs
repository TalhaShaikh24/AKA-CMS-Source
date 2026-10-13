using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Manages roles and their permission assignments.</summary>
[ApiController]
[Route("api/roles")]
[Authorize]
public sealed class RolesController(IRoleService roleService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Get all.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<RoleDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.RolesRead)]
    public async Task<ActionResult<IReadOnlyList<RoleDto>>> GetAll()
        => Ok(await roleService.GetAllAsync());

    /// <summary>Get by id.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(RoleDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet("{id:int}")]
    [Authorize(Policy = PermissionPolicies.RolesRead)]
    public async Task<ActionResult<RoleDto>> GetById(int id)
        => Ok(await roleService.GetByIdAsync(id));

    /// <summary>Create.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(RoleDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.RolesWrite)]
    public async Task<ActionResult<RoleDto>> Create([FromBody] CreateRoleRequest request)
    {
        var role = await roleService.CreateAsync(request, currentUser.UserId);
        return CreatedAtAction(nameof(GetById), new { id = role.RoleId }, role);
    }

    /// <summary>Update a role's description.</summary>
    [HttpPut("{id:int}")]
    [Authorize(Policy = PermissionPolicies.RolesWrite)]
    public async Task<ActionResult<RoleDto>> Update(int id, [FromBody] UpdateRoleRequest request)
    {
        var role = await roleService.UpdateAsync(id, request, currentUser.UserId);
        return Ok(role);
    }

    /// <summary>Get permissions.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<PermissionDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet("{id:int}/permissions")]
    [Authorize(Policy = PermissionPolicies.RolesRead)]
    public async Task<ActionResult<IReadOnlyList<PermissionDto>>> GetPermissions(int id)
        => Ok(await roleService.GetPermissionsAsync(id));

    /// <summary>Assign permission.</summary>
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("{id:int}/permissions")]
    [Authorize(Policy = PermissionPolicies.RolesWrite)]
    public async Task<IActionResult> AssignPermission(int id, [FromBody] AssignPermissionRequest request)
    {
        await roleService.AssignPermissionAsync(id, request, currentUser.UserId, currentUser.Username);
        return NoContent();
    }

    /// <summary>Remove permission.</summary>
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpDelete("{id:int}/permissions/{controllerActionId:int}")]
    [Authorize(Policy = PermissionPolicies.RolesWrite)]
    public async Task<IActionResult> RemovePermission(int id, int controllerActionId)
    {
        await roleService.RemovePermissionAsync(id, controllerActionId, currentUser.UserId);
        return NoContent();
    }
}
