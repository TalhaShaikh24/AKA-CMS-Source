using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Screening Tools page shell. The view calls the Web API
/// directly (GET /api/screenings/tools, POST /api/screenings/submit,
/// GET /api/screenings/case/{id}) through the global cmsAjax helper.</summary>
public sealed class ScreeningController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
