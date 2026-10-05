using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Reports page shell (demo view, no API calls).</summary>
public sealed class ReportsController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
