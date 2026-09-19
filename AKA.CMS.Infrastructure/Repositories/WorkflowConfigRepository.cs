using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class WorkflowConfigRepository(DapperContext context) : IWorkflowConfigRepository
{
    public async Task<IReadOnlyList<WorkflowState>> GetStatesAsync()
    {
        using var connection = context.CreateConnection();
        var states = await connection.QueryAsync<WorkflowState>(
            StoredProcedures.WorkflowStateGetAll,
            commandType: CommandType.StoredProcedure);
        return states.ToList();
    }

    public async Task<IReadOnlyList<WorkflowTransition>> GetTransitionsAsync()
    {
        using var connection = context.CreateConnection();
        var transitions = await connection.QueryAsync<WorkflowTransition>(
            StoredProcedures.WorkflowTransitionGetAll,
            commandType: CommandType.StoredProcedure);
        return transitions.ToList();
    }

    public async Task<int> CreateTransitionAsync(
        string fromState, string actionCode, string actionName, string toState,
        string? requiredPermissionName, int sortOrder, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@FromState", fromState);
        parameters.Add("@ActionCode", actionCode);
        parameters.Add("@ActionName", actionName);
        parameters.Add("@ToState", toState);
        parameters.Add("@RequiredPermissionName", requiredPermissionName);
        parameters.Add("@SortOrder", sortOrder);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewTransitionId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.WorkflowTransitionCreate, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewTransitionId");
        }
        catch (SqlException ex) when (ex.Number == 50009)
        {
            throw new ScreeningValidationException(ex.Message);
        }
    }

    public async Task SetTransitionActiveAsync(
        int transitionId, bool isActive, byte[] rowVersion, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@TransitionId", transitionId);
        parameters.Add("@IsActive", isActive);
        parameters.Add("@RowVersion", rowVersion, DbType.Binary, size: 8);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.WorkflowTransitionSetActive, parameters,
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }
}
