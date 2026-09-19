using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Queries the audit trail (read-only).</summary>
[ApiController]
[Route("api/audit-logs")]
[Authorize]
public sealed class AuditLogsController(IAuditLogService auditLogService) : ControllerBase
{
    /// <summary>Query.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(AuditLogQueryResponse))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.AuditLogsRead)]
    public async Task<ActionResult<AuditLogQueryResponse>> Query(
        [FromQuery] string? tableName,
        [FromQuery] string? recordId,
        [FromQuery] int? performedBy,
        [FromQuery] DateTime? fromDate,
        [FromQuery] DateTime? toDate,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
        => Ok(await auditLogService.QueryAsync(new AuditLogQueryRequest(
            tableName, recordId, performedBy, fromDate, toDate, page, pageSize)));
}
