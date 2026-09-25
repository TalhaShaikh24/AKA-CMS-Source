using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Role and permission management. Same pattern as <see cref="UsersController"/>:
/// Razor views here, data straight from <see cref="IRoleService"/> /
/// <see cref="IPermissionService"/>, browser calls through cmsAjax.</summary>
[Authorize]
public sealed class RolesController(
    IRoleService roleService,
    IPermissionService permissionService,
    ICurrentUser currentUser) : Controller
{
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.RolesRead)]
    public IActionResult Index() => View();

    [HttpGet]
    [Authorize(Policy = PermissionPolicies.RolesRead)]
    public async Task<IActionResult> List() => Json(await roleService.GetAllAsync());

    [HttpPost]
    [Authorize(Policy = PermissionPolicies.RolesWrite)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create([FromBody] CreateRoleRequest request)
    {
        var role = await roleService.CreateAsync(request, currentUser.UserId);
        Response.StatusCode = StatusCodes.Status201Created;
        return Json(role);
    }

    [HttpGet]
    [Authorize(Policy = PermissionPolicies.RolesRead)]
    public async Task<IActionResult> Permissions(int id) =>
        Json(await roleService.GetPermissionsAsync(id));

    [HttpGet]
    [Authorize(Policy = PermissionPolicies.PermissionsRead)]
    public async Task<IActionResult> Catalog() => Json(await permissionService.GetCatalogAsync());

    [HttpPost]
    [Authorize(Policy = PermissionPolicies.RolesWrite)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> AssignPermission(int id, [FromBody] AssignPermissionRequest request)
    {
        await roleService.AssignPermissionAsync(id, request, currentUser.UserId, currentUser.Username);
        return NoContent();
    }

    [HttpDelete]
    [Authorize(Policy = PermissionPolicies.RolesWrite)]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> RemovePermission(int id, int controllerActionId)
    {
        await roleService.RemovePermissionAsync(id, controllerActionId, currentUser.UserId);
        return NoContent();
    }
}
