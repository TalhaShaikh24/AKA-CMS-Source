using AKA.CMS.Application.DTOs;
using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface INotificationRepository
{
    Task<int> CreateAsync(
        string? recipientRole, int? recipientUserId, string title, string body,
        int? relatedCaseId, string? relatedEntity, int? relatedEntityId,
        string? pushPayload, int createdBy);
    Task<(IReadOnlyList<Notification> Items, int TotalCount)> GetByUserAsync(
        int userId, bool unreadOnly, int page, int pageSize);
    Task MarkAsReadAsync(int notificationId, int userId);
    Task<int> MarkAllReadAsync(int userId);
}
