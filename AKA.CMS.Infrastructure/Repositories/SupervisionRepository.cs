using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class SupervisionRepository(DapperContext context) : ISupervisionRepository
{
    public async Task<int> LogReviewAsync(
        int caseId, int supervisorUserId, DateTime reviewDate,
        string findings, string? actionItems, string? rating,
        int createdBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@SupervisorUserId", supervisorUserId);
        parameters.Add("@ReviewDate", reviewDate);
        parameters.Add("@Findings", findings);
        parameters.Add("@ActionItems", actionItems);
        parameters.Add("@Rating", rating);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewLogId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.SupervisionLogCreate, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewLogId");
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

    public async Task<IReadOnlyList<SupervisionLog>> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        var logs = await connection.QueryAsync<SupervisionLog>(
            StoredProcedures.SupervisionLogsGetByCase,
            new { CaseId = caseId },
            commandType: CommandType.StoredProcedure);
        return logs.ToList();
    }
}
