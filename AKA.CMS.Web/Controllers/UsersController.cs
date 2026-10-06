using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Users page shell. All data (list/create/update/roles)
/// is loaded by the view through cmsAjax calls to the Web API (/api/users).</summary>
public sealed class UsersController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();

    /// <summary>Serves the signed-in user's own profile editor. Any
    /// authenticated user may open it; the API enforces self-access.</summary>
    [HttpGet]
    public IActionResult Profile() => View();
}
