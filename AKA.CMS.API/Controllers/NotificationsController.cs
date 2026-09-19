using AKA.CMS.API.Auth;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Sends and reads user notifications.</summary>
[ApiController]
[Route("api/notifications")]
[Authorize]
public sealed class NotificationsController(
    INotificationService notificationService, ICurrentUser currentUser) : ControllerBase
{
    /// <summary>Get by user.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(NotificationListResponse))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpGet]
    [Authorize(Policy = PermissionPolicies.NotificationsRead)]
    public async Task<ActionResult<NotificationListResponse>> GetByUser(
        [FromQuery] bool unreadOnly = false,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
        => Ok(await notificationService.GetByUserAsync(
            currentUser.UserId, unreadOnly, page, pageSize));

    /// <summary>Send.</summary>
    [ProducesResponseType(StatusCodes.Status201Created, Type = typeof(NotificationDto))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost]
    [Authorize(Policy = PermissionPolicies.NotificationsWrite)]
    public async Task<ActionResult<NotificationDto>> Send(
        [FromBody] CreateNotificationRequest request)
    {
        var notification = await notificationService.SendAsync(request, currentUser.UserId);
        return CreatedAtAction(nameof(GetByUser), new { }, notification);
    }

    /// <summary>Mark as read.</summary>
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status404NotFound, Type = typeof(ProblemDetails))]
    [HttpPatch("{id:int}/read")]
    [Authorize(Policy = PermissionPolicies.NotificationsWrite)]
    public async Task<ActionResult> MarkAsRead(int id)
    {
        await notificationService.MarkAsReadAsync(id, currentUser.UserId);
        return NoContent();
    }

    /// <summary>Mark all read.</summary>
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(MarkAllReadResponse))]
    [ProducesResponseType(StatusCodes.Status401Unauthorized, Type = typeof(ProblemDetails))]
    [ProducesResponseType(StatusCodes.Status403Forbidden, Type = typeof(ProblemDetails))]
    [HttpPost("read-all")]
    [Authorize(Policy = PermissionPolicies.NotificationsWrite)]
    public async Task<ActionResult<MarkAllReadResponse>> MarkAllRead()
        => Ok(new MarkAllReadResponse(await notificationService.MarkAllReadAsync(currentUser.UserId)));
}
