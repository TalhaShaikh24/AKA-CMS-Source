using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Workflow roles: the list of who a workflow step can wait
/// on, and which users hold each one. Separate from user roles
/// (ROLES) — assigning a workflow role to a user is optional.
/// Permissions are dynamic like every other module
/// (WorkflowRoles:Read/Write from AllCONTROLLERS).</summary>
[ApiController]
[Route("api/workflow-roles")]
[Authorize]
public sealed class WorkflowRolesController(
    IWorkflowRoleService service, IUserService users, ICurrentUser currentUser) : ControllerBase
{
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.WorkflowRolesRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<WorkflowRoleDto>))]
    public async Task<ActionResult<IReadOnlyList<WorkflowRoleDto>>> GetAll()
        => Ok(await service.GetAllAsync());

    [HttpGet("{id:int}")]
    [Authorize(Policy = PermissionPolicies.WorkflowRolesRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(WorkflowRoleDto))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowRoleDto>> GetById(int id)
        => Ok(await service.GetByIdAsync(id));

    [HttpPost]
    [Authorize(Policy = PermissionPolicies.WorkflowRolesWrite)]
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(WorkflowRoleDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowRoleDto>> Create([FromBody] SaveWorkflowRoleRequest request)
    {
        var created = await service.CreateAsync(request, currentUser.UserId);
        return CreatedAtAction(nameof(GetById), new { id = created.WorkflowRoleId }, created);
    }

    [HttpPut("{id:int}")]
    [Authorize(Policy = PermissionPolicies.WorkflowRolesWrite)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(WorkflowRoleDto))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<WorkflowRoleDto>> Update(int id, [FromBody] SaveWorkflowRoleRequest request)
        => Ok(await service.UpdateAsync(id, request, currentUser.UserId));

    [HttpDelete("{id:int}")]
    [Authorize(Policy = PermissionPolicies.WorkflowRolesWrite)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<IActionResult> Delete(int id)
    {
        await service.DeleteAsync(id, currentUser.UserId);
        return NoContent();
    }

    /// <summary>Users holding this workflow role (for the assign
    /// picker on the Workflow Roles page).</summary>
    [HttpGet("{id:int}/users")]
    [Authorize(Policy = PermissionPolicies.WorkflowRolesRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<WorkflowRoleUserDto>))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<IReadOnlyList<WorkflowRoleUserDto>>> GetUsersByRole(int id)
        => Ok(await service.GetUsersByRoleAsync(id));

    /// <summary>Replace the users holding this workflow role.</summary>
    [HttpPut("{id:int}/users")]
    [Authorize(Policy = PermissionPolicies.WorkflowRolesWrite)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    public async Task<IActionResult> SaveUsersByRole(int id, [FromBody] SaveWorkflowRoleUsersRequest request)
    {
        await service.SaveUsersByRoleAsync(id, request.UserIds, currentUser.UserId);
        return NoContent();
    }

    /// <summary>All users, for the assign picker — under this
    /// module's own permission, so the page does not also need
    /// Users:Read.</summary>
    [HttpGet("users")]
    [Authorize(Policy = PermissionPolicies.WorkflowRolesRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<UserDto>))]
    public async Task<ActionResult<IReadOnlyList<UserDto>>> GetAllUsers()
        => Ok(await users.GetAllAsync());

    /// <summary>Workflow roles one user holds.</summary>
    [HttpGet("users/{userId:int}/roles")]
    [Authorize(Policy = PermissionPolicies.WorkflowRolesRead)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<UserWorkflowRoleDto>))]
    public async Task<ActionResult<IReadOnlyList<UserWorkflowRoleDto>>> GetByUser(int userId)
        => Ok(await service.GetByUserAsync(userId));
}
