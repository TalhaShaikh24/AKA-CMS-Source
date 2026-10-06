using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the auth pages. Authentication itself happens in the browser:
/// the views post to the Web API through the global cmsAjax helper and keep
/// the JWT. This controller never touches credentials.</summary>
public sealed class AccountController : Controller
{
    [HttpGet]
    public IActionResult Login() => View();

    [HttpGet]
    public IActionResult ForgotPassword() => View();

    [HttpGet]
    public IActionResult ResetPassword() => View();

    [HttpGet]
    public IActionResult Logout() => RedirectToAction(nameof(Login));
}
