using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Workflow management pages. All data is loaded by
/// the views through cmsAjax calls to the Web API (/api/workflows).</summary>
public sealed class WorkflowsController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();

    /// <summary>Manage one workflow: its steps, each step's sections
    /// and each step's buttons.</summary>
    [HttpGet]
    public IActionResult Manage(int id)
    {
        ViewBag.WorkflowId = id;
        return View();
    }
}
