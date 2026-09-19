using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Liveness probe for load balancers / uptime monitors. Anonymous on purpose.</summary>
[ApiController]
[Route("api/health")]
[AllowAnonymous]
public sealed class HealthController(
    IHealthService healthService, ILogger<HealthController> logger) : ControllerBase
{
    /// <summary>Returns 200 when the API and its database are reachable, 503 otherwise.</summary>
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(HealthCheckResponse))]
    [ProducesResponseType(StatusCodes.Status503ServiceUnavailable, Type = typeof(ProblemDetails))]
    public async Task<ActionResult<HealthCheckResponse>> Get()
    {
        try
        {
            return Ok(await healthService.CheckAsync());
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Health check failed: database ping unsuccessful.");
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new ProblemDetails
            {
                Status = StatusCodes.Status503ServiceUnavailable,
                Title = "Service unavailable.",
                Detail = "Database ping failed.",
                Instance = HttpContext.Request.Path
            });
        }
    }
}
