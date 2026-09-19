using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class AuditLogService(
    IAuditLogRepository auditLogRepository,
    IValidator<AuditLogQueryRequest> queryValidator) : IAuditLogService
{
    public async Task<AuditLogQueryResponse> QueryAsync(AuditLogQueryRequest request)
    {
        await queryValidator.ValidateAndThrowAsync(request);

        var page = Math.Max(1, request.Page);
        var pageSize = Math.Clamp(request.PageSize, 1, 100);
        var (items, total) = await auditLogRepository.QueryAsync(
            request.TableName, request.RecordId, request.PerformedBy,
            request.FromDate, request.ToDate, page, pageSize);
        return new AuditLogQueryResponse(items.ToList(), total, page, pageSize);
    }
}
