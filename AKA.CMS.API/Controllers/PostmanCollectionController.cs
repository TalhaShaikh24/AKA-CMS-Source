using System.Text;
using AKA.CMS.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Downloads a Postman Collection v2.1 generated live from this API's
/// OpenAPI description. Hidden from Swagger/ApiExplorer itself — the Swagger
/// page links here through its "Download Postman Collection" button.</summary>
[ApiController]
[Route("api/postman-collection")]
[AllowAnonymous]
[ApiExplorerSettings(IgnoreApi = true)]
public sealed class PostmanCollectionController(PostmanCollectionBuilder builder) : ControllerBase
{
    [HttpGet]
    public IActionResult Download()
    {
        var json = builder.BuildJson(Request);
        return File(Encoding.UTF8.GetBytes(json), "application/json",
            "AKA-CMS-Postman-Collection.json");
    }
}
