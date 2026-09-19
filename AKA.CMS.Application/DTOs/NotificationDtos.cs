namespace AKA.CMS.Application.DTOs;

public sealed record NotificationDto(
    int NotificationId,
    string? RecipientRole,
    int? RecipientUserId,
    string Title,
    string Body,
    int? RelatedCaseId,
    string? RelatedEntity,
    int? RelatedEntityId,
    bool IsRead,
    DateTime? ReadAt,
    string Status,
    string? PushPayload,
    DateTime CreatedAt);

public sealed record CreateNotificationRequest(
    string? RecipientRole,
    int? RecipientUserId,
    string Title,
    string Body,
    int? RelatedCaseId,
    string? RelatedEntity,
    int? RelatedEntityId,
    string? PushPayload);

public sealed record NotificationListResponse(
    IReadOnlyList<NotificationDto> Items,
    long TotalCount,
    int Page,
    int PageSize)
    : PagedResult<NotificationDto>(Items, TotalCount, Page, PageSize);

public sealed record MarkAllReadResponse(int MarkedCount);
