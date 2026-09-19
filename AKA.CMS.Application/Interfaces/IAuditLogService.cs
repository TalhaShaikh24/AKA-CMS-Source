using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IAuditLogService
{
    Task<AuditLogQueryResponse> QueryAsync(AuditLogQueryRequest request);
}
