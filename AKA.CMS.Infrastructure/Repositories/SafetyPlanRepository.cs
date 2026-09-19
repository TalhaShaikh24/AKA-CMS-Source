using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class SafetyPlanRepository(DapperContext context) : ISafetyPlanRepository
{
    public async Task<int> CreateAsync(
        int caseId, string warningSigns, string copingStrategies,
        string? supportContactsJson, int createdBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@WarningSigns", warningSigns);
        parameters.Add("@CopingStrategies", copingStrategies);
        parameters.Add("@SupportContactsJson", supportContactsJson);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewPlanId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.SafetyPlanCreate, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewPlanId");
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50010)
        {
            throw new InvalidDomainValueException(ex.Message);
        }
    }

    public async Task<SafetyPlan> GetByIdAsync(int planId)
    {
        using var connection = context.CreateConnection();
        try
        {
            return await connection.QuerySingleAsync<SafetyPlan>(
                StoredProcedures.SafetyPlanGetById,
                new { SafetyPlanId = planId },
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }

    public async Task<IReadOnlyList<SafetyPlan>> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        try
        {
            var plans = await connection.QueryAsync<SafetyPlan>(
                StoredProcedures.SafetyPlanGetByCase,
                new { CaseId = caseId },
                commandType: CommandType.StoredProcedure);
            return plans.ToList();
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }
}
