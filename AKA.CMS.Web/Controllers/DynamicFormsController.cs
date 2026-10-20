using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Dynamic Form Builder pages. All data is loaded by
/// the views through cmsAjax calls to the Web API (/api/dynamic-forms).</summary>
public sealed class DynamicFormsController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();

    [HttpGet]
    public IActionResult Builder(int? id)
    {
        ViewBag.FormId = id;
        return View();
    }

    [HttpGet]
    public IActionResult Render(int id)
    {
        ViewBag.FormId = id;
        return View();
    }
}
