using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Cases pages shells (demo views, no API calls).</summary>
public sealed class CasesController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();

    [HttpGet]
    public IActionResult Add() => View();

    [HttpGet]
    public IActionResult Details() => View();

    [HttpGet]
    public IActionResult Timeline() => View();
}
