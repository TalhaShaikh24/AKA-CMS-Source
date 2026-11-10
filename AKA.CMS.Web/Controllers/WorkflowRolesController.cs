using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Workflow Roles page (the workflow-role list
/// and which users hold each role). All data is loaded by the view
/// through cmsAjax calls to /api/workflow-roles.</summary>
public sealed class WorkflowRolesController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
