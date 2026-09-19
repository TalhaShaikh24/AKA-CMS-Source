using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class PermissionRepository(DapperContext context) : IPermissionRepository
{
    public async Task<IReadOnlyList<ControllerAction>> GetCatalogAsync()
    {
        using var connection = context.CreateConnection();
        var catalog = await connection.QueryAsync<ControllerAction>(
            StoredProcedures.PermissionGetCatalog, commandType: CommandType.StoredProcedure);
        return catalog.ToList();
    }
}
