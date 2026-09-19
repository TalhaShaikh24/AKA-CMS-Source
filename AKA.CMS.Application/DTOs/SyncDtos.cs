namespace AKA.CMS.Application.DTOs;

public sealed record SyncPushRequest(
    string IdempotencyKey,
    string DeviceId,
    string EntityType,
    int? EntityId,
    string Action,
    string PayloadJson,
    DateTime? BaseVersion);

public sealed record SyncPushResponse(
    int OutboxId,
    string Status,
    bool IsDuplicate,
    string? ConflictReportJson);

public sealed record SyncPullItemDto(
    long ChangeId,
    string EntityType,
    string EntityId,
    string Action,
    int? PerformedBy,
    DateTime ChangedAt,
    string? Details);

public sealed record SyncPullResponse(
    IReadOnlyList<SyncPullItemDto> Items,
    long TotalCount,
    DateTime Watermark,
    int Page,
    int PageSize)
    : PagedResult<SyncPullItemDto>(Items, TotalCount, Page, PageSize);

public sealed record SyncAckRequest(
    string IdempotencyKey,
    string DeviceId);

public sealed record SyncAckResponse(
    string IdempotencyKey,
    bool Acknowledged);
