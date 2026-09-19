using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>
/// Offline outbox contract for the Flutter app. Pushes are idempotent via
/// the client-generated IdempotencyKey: a duplicate key returns the
/// existing record with a 409 (treat as "already processed", never retry
/// with a new key). Conflict strategy is server-wins — on Status=Conflict
/// re-fetch via pull and reconcile locally.
/// </summary>
[ApiController]
[Route("api/sync")]
[Authorize]
public sealed class SyncController(
    ISyncService syncService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Pushes one offline change; duplicates return 409 with the existing record.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(SyncPushResponse))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status409Conflict, Type = typeof(ProblemDetails))]
    [HttpPost("push")]
    [Authorize(Policy = PermissionPolicies.SyncWrite)]
    public async Task<ActionResult<SyncPushResponse>> Push(
        [FromBody] SyncPushRequest request)
    {
        var result = await syncService.PushAsync(request, currentUser.UserId);
        return result.IsDuplicate
            ? Conflict(result)
            : Ok(result);
    }

    /// <summary>Pulls server-side changes since a watermark, paginated.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(SyncPullResponse))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet("pull")]
    [Authorize(Policy = PermissionPolicies.SyncRead)]
    public async Task<ActionResult<SyncPullResponse>> Pull(
        [FromQuery] DateTime since,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 100)
        => Ok(await syncService.PullAsync(since, page, pageSize));

    /// <summary>Acknowledges receipt of a pushed change.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(SyncAckResponse))]
    [ProducesResponseType(StatusCodes.Status400BadRequest, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("ack")]
    [Authorize(Policy = PermissionPolicies.SyncWrite)]
    public async Task<ActionResult<SyncAckResponse>> Acknowledge(
        [FromBody] SyncAckRequest request)
        => Ok(await syncService.AcknowledgeAsync(request, currentUser.UserId));
}
