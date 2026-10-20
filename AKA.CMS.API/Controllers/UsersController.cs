using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Manages users and their role assignments.</summary>
[ApiController]
[Route("api/users")]
[Authorize]
public sealed class UsersController(IUserService userService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Get all.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<UserDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.UsersRead)]
    public async Task<ActionResult<IReadOnlyList<UserDto>>> GetAll()
        => Ok(await userService.GetAllAsync());

    /// <summary>Get the signed-in user's own profile.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(UserDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet("me")]
    [Authorize]
    public async Task<ActionResult<UserDto>> GetMe()
        => Ok(await userService.GetByIdAsync(currentUser.UserId));

    /// <summary>Update the signed-in user's own profile (e-mail / password).
    /// No admin permission needed; admin-only flags cannot be changed here.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(UserDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpPut("me")]
    [Authorize]
    public async Task<ActionResult<UserDto>> UpdateMe([FromBody] UpdateMyProfileRequest request)
        => Ok(await userService.UpdateMyProfileAsync(currentUser.UserId, request));

    /// <summary>Active Directory user list (dummy data until real AD config is
    /// provided) — pick a user here and create them with UserType = "AD".</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(IReadOnlyList<AdDirectoryUserDto>))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("ad-directory")]
    [Authorize(Policy = PermissionPolicies.UsersWrite)]
    public async Task<ActionResult<IReadOnlyList<AdDirectoryUserDto>>> GetAdDirectory()
        => Ok(await userService.GetAdDirectoryAsync());

    /// <summary>Get by id.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(UserDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet("{id:int}")]
    [Authorize(Policy = PermissionPolicies.UsersRead)]
    public async Task<ActionResult<UserDto>> GetById(int id)
        => Ok(await userService.GetByIdAsync(id));

    /// <summary>Create.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(UserDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.UsersWrite)]
    public async Task<ActionResult<UserDto>> Create([FromBody] CreateUserRequest request)
    {
        var created = await userService.CreateAsync(request, currentUser.UserId, currentUser.Username);
        return CreatedAtAction(nameof(GetById), new { id = created.UserId }, created);
    }

    /// <summary>Update.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(UserDto))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpPut("{id:int}")]
    [Authorize(Policy = PermissionPolicies.UsersWrite)]
    public async Task<ActionResult<UserDto>> Update(int id, [FromBody] UpdateUserRequest request)
        => Ok(await userService.UpdateAsync(id, request, currentUser.UserId));

    /// <summary>Assign role.</summary>
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("{id:int}/roles")]
    [Authorize(Policy = PermissionPolicies.UsersWrite)]
    public async Task<IActionResult> AssignRole(int id, [FromBody] AssignRoleRequest request)
    {
        await userService.AssignRoleAsync(id, request, currentUser.UserId, currentUser.Username);
        return NoContent();
    }

    /// <summary>Remove role.</summary>
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpDelete("{id:int}/roles/{roleId:int}")]
    [Authorize(Policy = PermissionPolicies.UsersWrite)]
    public async Task<IActionResult> RemoveRole(int id, int roleId)
    {
        await userService.RemoveRoleAsync(id, roleId, currentUser.UserId);
        return NoContent();
    }
}
