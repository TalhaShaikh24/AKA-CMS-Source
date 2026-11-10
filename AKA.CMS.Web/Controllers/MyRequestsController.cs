using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the My Requests page (workflow instances the
/// logged-in user started themselves). All data is loaded by the
/// view through cmsAjax calls to /api/workflow-instances.</summary>
public sealed class MyRequestsController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
