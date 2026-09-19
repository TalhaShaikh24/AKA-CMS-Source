using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IAuditLogRepository
{
    Task<(IReadOnlyList<AuditLogDto> Items, long TotalCount)> QueryAsync(
        string? tableName, string? recordId, int? performedBy,
        DateTime? fromDate, DateTime? toDate, int page, int pageSize);
}
