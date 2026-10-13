using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Screening Tools page shell. All data is loaded by
/// the view through cmsAjax calls to the Web API (/api/screening-tools).</summary>
public sealed class ScreeningToolsController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
