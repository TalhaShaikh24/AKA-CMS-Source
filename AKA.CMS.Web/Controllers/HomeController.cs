using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

public sealed class HomeController : Controller
{
    public IActionResult Index() => RedirectToAction("Login", "Account");

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error() => View();
}
