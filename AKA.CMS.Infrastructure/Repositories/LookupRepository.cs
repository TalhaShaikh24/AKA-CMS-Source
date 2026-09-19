using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class LookupRepository(DapperContext context) : ILookupRepository
{
    public async Task<IReadOnlyList<LookupItem>> GetByTypeAsync(string lookupType)
    {
        using var connection = context.CreateConnection();
        try
        {
            var items = await connection.QueryAsync<LookupItem>(
                StoredProcedures.LookupGet,
                new { LookupType = lookupType },
                commandType: CommandType.StoredProcedure);
            return items.ToList();
        }
        catch (SqlException ex) when (ex.Number == 50009)
        {
            throw new ScreeningValidationException(ex.Message);
        }
    }
}
