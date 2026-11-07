using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the My Tasks page (workflow instances waiting for
/// the logged-in user's roles). All data is loaded by the view
/// through cmsAjax calls to /api/workflow-instances.</summary>
public sealed class MyTasksController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
