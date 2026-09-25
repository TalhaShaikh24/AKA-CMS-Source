using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Team-member management. The Razor view is rendered by this MVC app;
/// all data operations go straight to <see cref="IUserService"/> — no HTTP
/// calls to the Web API. Browser-side calls use the global cmsAjax helper.</summary>
[Authorize]
public sealed class UsersController(IUserService userService, ICurrentUser currentUser) : Controller
{
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.UsersRead)]
    public IActionResult Index() => View();

    [HttpGet]
    [Authorize(Policy = PermissionPolicies.UsersRead)]
    public async Task<IActionResult> List() => Json(await userService.GetAllAsync());

    [HttpGet]
    [Authorize(Policy = PermissionPolicies.RolesRead)]
    public async Task<IActionResult> Roles([FromServices] IRoleService roleService) =>
        Json(await roleService.GetAllAsync());

    [HttpPost]
    [Authorize(Policy = PermissionPolicies.UsersWrite)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create([FromBody] CreateUserRequest request)
    {
        var created = await userService.CreateAsync(request, currentUser.UserId, currentUser.Username);
        Response.StatusCode = StatusCodes.Status201Created;
        return Json(created);
    }

    [HttpPut]
    [Authorize(Policy = PermissionPolicies.UsersWrite)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateUserRequest request) =>
        Json(await userService.UpdateAsync(id, request, currentUser.UserId));

    [HttpPost]
    [Authorize(Policy = PermissionPolicies.UsersWrite)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AssignRole(int id, [FromBody] AssignRoleRequest request)
    {
        await userService.AssignRoleAsync(id, request, currentUser.UserId, currentUser.Username);
        return NoContent();
    }

    [HttpDelete]
    [Authorize(Policy = PermissionPolicies.UsersWrite)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> RemoveRole(int id, int roleId)
    {
        await userService.RemoveRoleAsync(id, roleId, currentUser.UserId);
        return NoContent();
    }
}
