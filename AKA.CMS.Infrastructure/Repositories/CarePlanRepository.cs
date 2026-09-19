using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class CarePlanRepository(DapperContext context) : ICarePlanRepository
{
    public async Task<IReadOnlyList<RiskRoutingRule>> GetRoutingRulesAsync()
    {
        using var connection = context.CreateConnection();
        var rules = await connection.QueryAsync<RiskRoutingRule>(
            StoredProcedures.RiskRoutingRuleGetAll, commandType: CommandType.StoredProcedure);
        return rules.ToList();
    }

    public async Task<int> CreateAsync(
        int caseId, string riskCategory, string? title, string? stepsJson,
        int createdBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@RiskCategory", riskCategory);
        parameters.Add("@Title", title);
        parameters.Add("@StepsJson", stepsJson);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewPlanId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.ActionCarePlanCreate, parameters,
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

    public async Task<IReadOnlyList<ActionCarePlan>> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        try
        {
            var plans = await connection.QueryAsync<ActionCarePlan>(
                StoredProcedures.ActionCarePlanGetByCase,
                new { CaseId = caseId }, commandType: CommandType.StoredProcedure);
            return plans.ToList();
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }
}
