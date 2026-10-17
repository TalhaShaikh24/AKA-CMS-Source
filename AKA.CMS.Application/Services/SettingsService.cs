using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;

namespace AKA.CMS.Application.Services;

public sealed class SettingsService(ISettingsRepository repository) : ISettingsService
{
    public async Task<UserProfileDto> GetProfileAsync(int userId)
        => await repository.GetProfileAsync(userId)
           ?? throw new NotFoundException($"User {userId} not found.");

    public async Task<UserProfileDto> SaveProfileAsync(int userId, UpdateProfileRequest request)
    {
        await repository.SaveProfileAsync(userId, request);
        return await GetProfileAsync(userId);
    }

    public Task<NotificationPrefsDto> GetNotificationsAsync(int userId)
        => repository.GetNotificationsAsync(userId);

    public async Task<NotificationPrefsDto> SaveNotificationsAsync(int userId, UpdateNotificationPrefsRequest request)
    {
        await repository.SaveNotificationsAsync(userId, request);
        return await repository.GetNotificationsAsync(userId);
    }

    public Task<SystemSettingsDto> GetSystemAsync()
        => repository.GetSystemAsync();

    public async Task<SystemSettingsDto> SaveSystemAsync(UpdateSystemSettingsRequest request, int updatedBy)
    {
        await repository.SaveSystemAsync(request, updatedBy);
        return await repository.GetSystemAsync();
    }
}
