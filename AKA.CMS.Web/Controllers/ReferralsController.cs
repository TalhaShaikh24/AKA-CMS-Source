using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Referrals page shells. All data is loaded by
/// the views through cmsAjax calls to the Web API (/api/referrals).</summary>
public sealed class ReferralsController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();

    [HttpGet]
    public IActionResult Create() => View();

    [HttpGet]
    public IActionResult Details(int id) => View(model: id);
}
