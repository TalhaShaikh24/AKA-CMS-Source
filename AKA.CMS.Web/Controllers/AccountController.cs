using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the login page. Authentication itself happens in the browser:
/// the login view posts credentials to POST /api/auth/login through the global
/// cmsAjax helper and keeps the JWT. This controller never touches credentials.</summary>
public sealed class AccountController : Controller
{
    [HttpGet]
    public IActionResult Login() => View();

    [HttpGet]
    public IActionResult Logout() => RedirectToAction(nameof(Login));
}
