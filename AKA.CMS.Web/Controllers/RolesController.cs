using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Roles &amp; Permissions page shell. All data is loaded by
/// the view through cmsAjax calls to the Web API (/api/roles, /api/permissions).</summary>
public sealed class RolesController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
