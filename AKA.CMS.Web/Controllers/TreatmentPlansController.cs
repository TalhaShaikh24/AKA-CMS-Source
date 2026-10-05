using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Treatment Plan page shell (demo view, no API calls).</summary>
public sealed class TreatmentPlansController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
