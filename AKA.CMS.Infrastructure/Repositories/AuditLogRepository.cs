using System.Data;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class AuditLogRepository(DapperContext context) : IAuditLogRepository
{
    public async Task<(IReadOnlyList<AuditLogDto> Items, long TotalCount)> QueryAsync(
        string? tableName, string? recordId, int? performedBy,
        DateTime? fromDate, DateTime? toDate, int page, int pageSize)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@TableName", tableName);
        parameters.Add("@RecordId", recordId);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@FromDate", fromDate);
        parameters.Add("@ToDate", toDate);
        parameters.Add("@Page", page);
        parameters.Add("@PageSize", pageSize);
        parameters.Add("@TotalCount", dbType: DbType.Int64, direction: ParameterDirection.Output);
        var items = await connection.QueryAsync<AuditLogDto>(
            StoredProcedures.AuditLogQuery, parameters,
            commandType: CommandType.StoredProcedure);
        return (items.ToList(), parameters.Get<long>("@TotalCount"));
    }
}
