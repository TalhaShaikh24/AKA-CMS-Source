namespace AKA.CMS.Application.DTOs;

public sealed record CaseListItemDto(
    int CaseId,
    string? CaseNumber,
    string? MemberName,
    string? MemberMrNo,
    string Status,
    string? StatusName,
    string? PriorityLevel,
    DateTime CreatedAt);

public sealed record CaseListResponse(
    IReadOnlyList<CaseListItemDto> Items,
    long TotalCount,
    int Page,
    int PageSize)
    : PagedResult<CaseListItemDto>(Items, TotalCount, Page, PageSize);
