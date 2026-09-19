using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Aggregate reports and dashboard figures.</summary>
[ApiController]
[Route("api/reports")]
[Authorize]
public sealed class ReportsController(IReportService reportService) : ControllerBase
{
    /// <summary>Get case summary.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(CaseSummaryDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("case-summary")]
    [Authorize(Policy = PermissionPolicies.ReportsRead)]
    public async Task<ActionResult<CaseSummaryDto>> GetCaseSummary(
        [FromQuery(Name = "from")] DateTime? from,
        [FromQuery(Name = "to")] DateTime? to,
        [FromQuery] int? unitCode)
        => Ok(await reportService.GetCaseSummaryAsync(from, to, unitCode));

    /// <summary>Get screening summary.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(ScreeningSummaryDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("screening-summary")]
    [Authorize(Policy = PermissionPolicies.ReportsRead)]
    public async Task<ActionResult<ScreeningSummaryDto>> GetScreeningSummary(
        [FromQuery] string? toolCode,
        [FromQuery(Name = "from")] DateTime? from,
        [FromQuery(Name = "to")] DateTime? to)
        => Ok(await reportService.GetScreeningSummaryAsync(toolCode, from, to));

    /// <summary>Get helpline summary.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(HelplineSummaryDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("helpline-summary")]
    [Authorize(Policy = PermissionPolicies.ReportsRead)]
    public async Task<ActionResult<HelplineSummaryDto>> GetHelplineSummary(
        [FromQuery(Name = "from")] DateTime? from,
        [FromQuery(Name = "to")] DateTime? to)
        => Ok(await reportService.GetHelplineSummaryAsync(from, to));

    /// <summary>Get follow up compliance.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(FollowUpComplianceDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("followup-compliance")]
    [Authorize(Policy = PermissionPolicies.ReportsRead)]
    public async Task<ActionResult<FollowUpComplianceDto>> GetFollowUpCompliance(
        [FromQuery(Name = "from")] DateTime? from,
        [FromQuery(Name = "to")] DateTime? to,
        [FromQuery] int? unitCode)
        => Ok(await reportService.GetFollowUpComplianceAsync(from, to, unitCode));

    /// <summary>Get workload.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(WorkloadDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("workload")]
    [Authorize(Policy = PermissionPolicies.ReportsRead)]
    public async Task<ActionResult<WorkloadDto>> GetWorkload([FromQuery] int? unitCode)
        => Ok(await reportService.GetWorkloadAsync(unitCode));
}
