using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Facilities page shell. All data is loaded by
/// the view through cmsAjax calls to the Web API (/api/facilities).</summary>
public sealed class FacilitiesController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
