using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Dashboard page shell (demo view, no API calls).</summary>
public sealed class DashboardController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
