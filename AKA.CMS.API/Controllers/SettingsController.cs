using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.API.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AKA.CMS.API.Controllers;

/// <summary>Settings page: profile, notification preferences, system settings.</summary>
[ApiController]
[Route("api/settings")]
[Authorize]
public sealed class SettingsController : ControllerBase
{
    private readonly ISettingsService _service;
    private readonly ICurrentUser _currentUser;

    public SettingsController(ISettingsService service, ICurrentUser currentUser)
    {
        _service = service;
        _currentUser = currentUser;
    }

    [HttpGet("profile")]
    public async Task<ActionResult<UserProfileDto>> GetProfile()
        => Ok(await _service.GetProfileAsync(_currentUser.UserId));

    [HttpPut("profile")]
    public async Task<ActionResult<UserProfileDto>> SaveProfile([FromBody] UpdateProfileRequest request)
        => Ok(await _service.SaveProfileAsync(_currentUser.UserId, request));

    [HttpGet("notifications")]
    public async Task<ActionResult<NotificationPrefsDto>> GetNotifications()
        => Ok(await _service.GetNotificationsAsync(_currentUser.UserId));

    [HttpPut("notifications")]
    public async Task<ActionResult<NotificationPrefsDto>> SaveNotifications([FromBody] UpdateNotificationPrefsRequest request)
        => Ok(await _service.SaveNotificationsAsync(_currentUser.UserId, request));

    [HttpGet("system")]
    public async Task<ActionResult<SystemSettingsDto>> GetSystem()
        => Ok(await _service.GetSystemAsync());

    [HttpPut("system")]
    public async Task<ActionResult<SystemSettingsDto>> SaveSystem([FromBody] UpdateSystemSettingsRequest request)
        => Ok(await _service.SaveSystemAsync(request, _currentUser.UserId));
}
