namespace AKA.CMS.Application.DTOs;

public sealed record AuditLogDto(
    long Id,
    string TableName,
    string RecordId,
    string Action,
    int? PerformedBy,
    DateTime PerformedAt,
    string? Details);

public sealed record AuditLogQueryRequest(
    string? TableName,
    string? RecordId,
    int? PerformedBy,
    DateTime? FromDate,
    DateTime? ToDate,
    int Page,
    int PageSize);

public sealed record AuditLogQueryResponse(
    IReadOnlyList<AuditLogDto> Items,
    long TotalCount,
    int Page,
    int PageSize)
    : PagedResult<AuditLogDto>(Items, TotalCount, Page, PageSize);
