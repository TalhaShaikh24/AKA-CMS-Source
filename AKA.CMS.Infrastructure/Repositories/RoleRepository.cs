using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class RoleRepository(DapperContext context) : IRoleRepository
{
    public async Task<IReadOnlyList<Role>> GetAllAsync()
    {
        using var connection = context.CreateConnection();
        var roles = await connection.QueryAsync<Role>(
            StoredProcedures.RoleGetAll, commandType: CommandType.StoredProcedure);
        return roles.ToList();
    }

    public async Task<Role?> GetByIdAsync(int roleId)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@RoleId", roleId);
        return await connection.QuerySingleOrDefaultAsync<Role>(
            StoredProcedures.RoleGetById, parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<int> CreateAsync(string description, int performedBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@Description", description);
        parameters.Add("@PerformedBy", performedBy);
        return await connection.QuerySingleAsync<int>(
            StoredProcedures.RoleCreate, parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task UpdateAsync(int roleId, string description, int performedBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@RoleId", roleId);
        parameters.Add("@Description", description);
        parameters.Add("@PerformedBy", performedBy);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.RoleUpdate, parameters, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }

    public async Task<IReadOnlyList<ControllerAction>> GetPermissionsAsync(int roleId)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@RoleId", roleId);
        var permissions = await connection.QueryAsync<ControllerAction>(
            StoredProcedures.RoleGetPermissions, parameters, commandType: CommandType.StoredProcedure);
        return permissions.ToList();
    }

    public async Task AssignPermissionAsync(int roleId, int controllerActionId, string createdBy, int performedBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@RoleId", roleId);
        parameters.Add("@ControllerActionId", controllerActionId);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@PerformedBy", performedBy);
        await connection.ExecuteAsync(
            StoredProcedures.RoleAssignPermission, parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task RemovePermissionAsync(int roleId, int controllerActionId, int performedBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@RoleId", roleId);
        parameters.Add("@ControllerActionId", controllerActionId);
        parameters.Add("@PerformedBy", performedBy);
        await connection.ExecuteAsync(
            StoredProcedures.RoleRemovePermission, parameters, commandType: CommandType.StoredProcedure);
    }
}
