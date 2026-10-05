using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class CaseRepository(DapperContext context) : ICaseRepository
{
    public async Task<int> CreateAsync(
        int communityMemberId, string sourceType, string? priorityLevel, string? notes,
        int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CommunityMemberId", communityMemberId);
        parameters.Add("@SourceType", sourceType);
        parameters.Add("@PriorityLevel", priorityLevel);
        parameters.Add("@Notes", notes);
        parameters.Add("@CreatedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewCaseId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.CaseCreate, parameters, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException($"Community member {communityMemberId} not found.");
        }
        return parameters.Get<int>("@NewCaseId");
    }

    public async Task<Case?> GetByIdAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        return await connection.QuerySingleOrDefaultAsync<Case>(
            StoredProcedures.CaseGetById, parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<Case> UpdateDetailsAsync(
        int caseId, string? priorityLevel, string? notes, byte[] rowVersion,
        int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@PriorityLevel", priorityLevel);
        parameters.Add("@Notes", notes);
        parameters.Add("@RowVersion", rowVersion);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        try
        {
            return await connection.QuerySingleAsync<Case>(
                StoredProcedures.CaseUpdateDetails, parameters, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException($"Case {caseId} not found.");
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException("The case was modified by another user. Reload and try again.");
        }
    }

    public async Task AssignAsync(
        int caseId, int userId, byte[] rowVersion, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@UserId", userId);
        parameters.Add("@RowVersion", rowVersion);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.CaseAssign, parameters, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException("Case or user not found.");
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException("The case was modified by another user. Reload and try again.");
        }
    }

    public async Task<Case> ApplyTransitionAsync(
        int caseId, string actionCode, string? comment, int? assignedToUserId,
        byte[] rowVersion, bool hasPermission, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@ActionCode", actionCode);
        parameters.Add("@Comment", comment);
        parameters.Add("@AssignedToUserId", assignedToUserId);
        parameters.Add("@RowVersion", rowVersion);
        parameters.Add("@HasPermission", hasPermission);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        try
        {
            return await connection.QuerySingleAsync<Case>(
                StoredProcedures.WorkflowTransitionApply, parameters,
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException("Case or user not found.");
        }
        catch (SqlException ex) when (ex.Number == 50006)
        {
            throw new WorkflowException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50007)
        {
            throw new ForbiddenException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException("The case was modified by another user. Reload and try again.");
        }
    }

    public async Task<IReadOnlyList<WorkflowTransition>> GetAllowedTransitionsAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        try
        {
            var transitions = await connection.QueryAsync<WorkflowTransition>(
                StoredProcedures.WorkflowTransitionGetAllowed, parameters,
                commandType: CommandType.StoredProcedure);
            return transitions.ToList();
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException($"Case {caseId} not found.");
        }
    }

    public async Task<IReadOnlyList<CaseHistory>> GetHistoryAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        try
        {
            var history = await connection.QueryAsync<CaseHistory>(
                StoredProcedures.CaseHistoryGetByCase, parameters,
                commandType: CommandType.StoredProcedure);
            return history.ToList();
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException($"Case {caseId} not found.");
        }
    }

    public async Task<IReadOnlyList<CaseListItem>> ListAsync(string? search, int page, int pageSize)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@Search", search);
        parameters.Add("@Page", page);
        parameters.Add("@PageSize", pageSize);
        var items = await connection.QueryAsync<CaseListItem>(
            StoredProcedures.CaseList, parameters,
            commandType: CommandType.StoredProcedure);
        return items.ToList();
    }
}
