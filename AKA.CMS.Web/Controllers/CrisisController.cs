using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the per-case Crisis Protocol page (mobile design flow:
/// protocol → 4-step response → escalation → timeline). All data is loaded
/// by the view through cmsAjax calls to the Web API.</summary>
public sealed class CrisisController : Controller
{
    [HttpGet]
    public IActionResult Case(int id) => View(model: id);
}
