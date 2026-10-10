using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Geography page shell. All data is loaded by
/// the view through cmsAjax calls to the Web API (/api/geography).</summary>
public sealed class GeographyController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
