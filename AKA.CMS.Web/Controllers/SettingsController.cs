using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Settings page shell (demo view, no API calls).</summary>
public sealed class SettingsController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
