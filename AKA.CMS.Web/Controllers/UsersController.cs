using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Users page shell. All data (list/create/update/roles)
/// is loaded by the view through cmsAjax calls to the Web API (/api/users).</summary>
public sealed class UsersController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
