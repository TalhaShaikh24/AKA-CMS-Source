namespace AKA.CMS.Application.DTOs;

/// <summary>
/// Canonical paginated-list envelope. Every paginated endpoint returns this
/// shape: <c>items</c>, <c>totalCount</c>, <c>page</c>, <c>pageSize</c>.
/// Endpoints may extend it with extra fields (e.g. a sync watermark), but the
/// four base properties are always present with the same names.
/// </summary>
public abstract record PagedResult<T>(
    IReadOnlyList<T> Items,
    long TotalCount,
    int Page,
    int PageSize);
