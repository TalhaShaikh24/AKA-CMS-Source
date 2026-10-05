using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Safety Plan page shell (demo view, no API calls).</summary>
public sealed class SafetyPlansController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
