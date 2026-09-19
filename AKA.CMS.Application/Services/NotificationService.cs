using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class NotificationService(
    INotificationRepository notificationRepository,
    IValidator<CreateNotificationRequest> sendValidator) : INotificationService
{
    public async Task<NotificationDto> SendAsync(CreateNotificationRequest request, int createdBy)
    {
        await sendValidator.ValidateAndThrowAsync(request);

        var id = await notificationRepository.CreateAsync(
            request.RecipientRole, request.RecipientUserId,
            request.Title, request.Body,
            request.RelatedCaseId, request.RelatedEntity, request.RelatedEntityId,
            request.PushPayload, createdBy);

        var (items, _) = await notificationRepository.GetByUserAsync(createdBy, false, 1, 100);
        return items.First(n => n.NotificationId == id).ToDto();
    }

    public async Task<NotificationListResponse> GetByUserAsync(
        int userId, bool unreadOnly, int page, int pageSize)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 100);
        var (items, total) = await notificationRepository.GetByUserAsync(userId, unreadOnly, page, pageSize);
        return new NotificationListResponse(items.Select(n => n.ToDto()).ToList(), total, page, pageSize);
    }

    public Task MarkAsReadAsync(int notificationId, int userId) =>
        notificationRepository.MarkAsReadAsync(notificationId, userId);

    public Task<int> MarkAllReadAsync(int userId) =>
        notificationRepository.MarkAllReadAsync(userId);
}
