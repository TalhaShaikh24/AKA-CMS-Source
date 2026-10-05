using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.Web.Controllers;

/// <summary>Serves the Appointments page shell (demo view, no API calls).</summary>
public sealed class AppointmentsController : Controller
{
    [HttpGet]
    public IActionResult Index() => View();
}
