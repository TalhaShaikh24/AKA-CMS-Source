using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Records and retrieves case-source mappings.</summary>
[ApiController]
[Route("api/cases/{id:int}/source")]
[Authorize]
public sealed class CaseSourceController(
    ICaseSourceService caseSourceService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Record.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(CaseSourceMappingDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.CaseSourcesWrite)]
    public async Task<ActionResult<CaseSourceMappingDto>> Record(
        int id, [FromBody] RecordCaseSourceRequest request)
    {
        var mapping = await caseSourceService.RecordAsync(id, request, currentUser.UserId, ClientIpAddress);
        return CreatedAtAction(nameof(GetByCase), new { id }, mapping);
    }

    /// <summary>Get by case.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(CaseSourceMappingDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.CaseSourcesRead)]
    public async Task<ActionResult<CaseSourceMappingDto>> GetByCase(int id)
    {
        var mapping = await caseSourceService.GetByCaseAsync(id);
        return mapping is null ? NotFound() : Ok(mapping);
    }

    private string ClientIpAddress =>
        HttpContext.Connection.RemoteIpAddress?.ToString() ?? "0.0.0.0";
}
