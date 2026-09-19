using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class HealthRepository(DapperContext context) : IHealthRepository
{
    public async Task<DateTime> CheckDatabaseAsync()
    {
        using var connection = context.CreateConnection();
        var row = await connection.QuerySingleAsync<HealthPing>(
            StoredProcedures.HealthCheck, commandType: CommandType.StoredProcedure);
        return row.DbUtcTime;
    }

    private sealed record HealthPing(int DbOk, DateTime DbUtcTime);
}
