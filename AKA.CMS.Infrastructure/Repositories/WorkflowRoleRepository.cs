using System.Data;
using System.Text.Json;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class WorkflowRoleRepository(DapperContext context) : IWorkflowRoleRepository
{
    public async Task<IReadOnlyList<WorkflowRoleDto>> GetAllAsync()
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<WorkflowRoleDto>(
            StoredProcedures.WorkflowRoleGetAll, commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    public async Task<WorkflowRoleDto?> GetByIdAsync(int workflowRoleId)
    {
        using var connection = context.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<WorkflowRoleDto>(
            StoredProcedures.WorkflowRoleGetById,
            new { WorkflowRoleId = workflowRoleId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> SaveAsync(int workflowRoleId, SaveWorkflowRoleRequest request, int performedBy)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@WorkflowRoleId", workflowRoleId);
        p.Add("@WorkflowRoleCode", request.WorkflowRoleCode);
        p.Add("@Title", request.Title);
        p.Add("@Description", request.Description);
        p.Add("@PerformedBy", performedBy);
        try
        {
            return await connection.QuerySingleAsync<int>(
                StoredProcedures.WorkflowRoleSave, p, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50000)
        {
            // The SP validates (duplicate code, missing title) and
            // THROWs 50000; surface it as a 400, not a 500.
            throw new InvalidDomainValueException(ex.Message);
        }
    }

    public async Task DeleteAsync(int workflowRoleId, int performedBy)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@WorkflowRoleId", workflowRoleId);
        p.Add("@PerformedBy", performedBy);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.WorkflowRoleDelete, p, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50000)
        {
            throw new InvalidDomainValueException(ex.Message);
        }
    }

    public async Task<IReadOnlyList<WorkflowRoleUserDto>> GetUsersByRoleAsync(int workflowRoleId)
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<WorkflowRoleUserDto>(
            StoredProcedures.UserWorkflowRoleGetUsersByRole,
            new { WorkflowRoleId = workflowRoleId },
            commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    public async Task SaveUsersByRoleAsync(int workflowRoleId, IReadOnlyList<int> userIds, int performedBy)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@WorkflowRoleId", workflowRoleId);
        p.Add("@UserIdsJson", JsonSerializer.Serialize(userIds));
        p.Add("@PerformedBy", performedBy);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.UserWorkflowRoleSaveByRole, p, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50000)
        {
            throw new InvalidDomainValueException(ex.Message);
        }
    }

    public async Task<IReadOnlyList<UserWorkflowRoleDto>> GetByUserAsync(int userId)
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<UserWorkflowRoleDto>(
            StoredProcedures.UserWorkflowRoleGetByUser,
            new { UserId = userId },
            commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }
}
