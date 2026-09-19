using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class TreatmentPlanRepository(DapperContext context) : ITreatmentPlanRepository
{
    public async Task<int> CreateAsync(
        int caseId, string planTrack, string title, string? goals,
        string? plannedInterventions, DateTime startDate, DateTime? plannedEndDate,
        int createdBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@PlanTrack", planTrack);
        parameters.Add("@Title", title);
        parameters.Add("@Goals", goals);
        parameters.Add("@PlannedInterventions", plannedInterventions);
        parameters.Add("@StartDate", startDate);
        parameters.Add("@PlannedEndDate", plannedEndDate);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewPlanId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.TreatmentPlanCreate, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewPlanId");
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50009)
        {
            throw new ScreeningValidationException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50010)
        {
            throw new InvalidDomainValueException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50011)
        {
            throw new ConflictException(ex.Message);
        }
    }

    public async Task UpdateAsync(
        int planId, string title, string? goals, string? plannedInterventions,
        DateTime? plannedEndDate, string status,
        byte[] rowVersion, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@PlanId", planId);
        parameters.Add("@Title", title);
        parameters.Add("@Goals", goals);
        parameters.Add("@PlannedInterventions", plannedInterventions);
        parameters.Add("@PlannedEndDate", plannedEndDate);
        parameters.Add("@Status", status);
        parameters.Add("@RowVersion", rowVersion);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.TreatmentPlanUpdate, parameters,
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
        catch (SqlException ex) when (ex.Number == 50009)
        {
            throw new ScreeningValidationException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50010)
        {
            throw new InvalidDomainValueException(ex.Message);
        }
    }

    public async Task<TreatmentPlan?> GetByIdAsync(int planId)
    {
        using var connection = context.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<TreatmentPlan>(
            StoredProcedures.TreatmentPlanGetById,
            new { PlanId = planId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IReadOnlyList<TreatmentPlan>> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        var plans = await connection.QueryAsync<TreatmentPlan>(
            StoredProcedures.TreatmentPlanGetByCase,
            new { CaseId = caseId },
            commandType: CommandType.StoredProcedure);
        return plans.ToList();
    }
}
