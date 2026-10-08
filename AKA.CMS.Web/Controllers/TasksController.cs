using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Tasks pages. All data is loaded by the views
/// through cmsAjax calls to the Web API (/api/tasks).</summary>
public sealed class TasksController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();

    [HttpGet]
    public IActionResult Create() => View();
}
