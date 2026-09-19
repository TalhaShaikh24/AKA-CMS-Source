using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface INotificationService
{
    Task<NotificationDto> SendAsync(CreateNotificationRequest request, int createdBy);
    Task<NotificationListResponse> GetByUserAsync(
        int userId, bool unreadOnly, int page, int pageSize);
    Task MarkAsReadAsync(int notificationId, int userId);
    Task<int> MarkAllReadAsync(int userId);
}
