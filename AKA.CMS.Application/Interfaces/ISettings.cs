using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface ISettingsRepository
{
    Task<UserProfileDto?> GetProfileAsync(int userId);
    Task SaveProfileAsync(int userId, UpdateProfileRequest request);
    Task<NotificationPrefsDto> GetNotificationsAsync(int userId);
    Task SaveNotificationsAsync(int userId, UpdateNotificationPrefsRequest request);
    Task<SystemSettingsDto> GetSystemAsync();
    Task SaveSystemAsync(UpdateSystemSettingsRequest request, int updatedBy);
}

public interface ISettingsService
{
    Task<UserProfileDto> GetProfileAsync(int userId);
    Task<UserProfileDto> SaveProfileAsync(int userId, UpdateProfileRequest request);
    Task<NotificationPrefsDto> GetNotificationsAsync(int userId);
    Task<NotificationPrefsDto> SaveNotificationsAsync(int userId, UpdateNotificationPrefsRequest request);
    Task<SystemSettingsDto> GetSystemAsync();
    Task<SystemSettingsDto> SaveSystemAsync(UpdateSystemSettingsRequest request, int updatedBy);
}
