using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class AssignmentQueueRepository(DapperContext context) : IAssignmentQueueRepository
{
    public async Task<int> EnqueueAsync(int caseId, string riskCategory, int enqueuedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@RiskCategory", riskCategory);
        parameters.Add("@EnqueuedBy", enqueuedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewQueueId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.AssignmentQueueEnqueue, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewQueueId");
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

    public async Task AssignAsync(
        int queueId, int assignedToUserId, byte[] rowVersion,
        int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@QueueId", queueId);
        parameters.Add("@AssignedToUserId", assignedToUserId);
        parameters.Add("@RowVersion", rowVersion, DbType.Binary);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.AssignmentQueueAssign, parameters,
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50010)
        {
            throw new InvalidDomainValueException(ex.Message);
        }
    }

    public async Task<IReadOnlyList<CaseAssignmentQueueEntry>> GetPendingAsync()
    {
        using var connection = context.CreateConnection();
        var entries = await connection.QueryAsync<CaseAssignmentQueueEntry>(
            StoredProcedures.AssignmentQueueGetPending,
            commandType: CommandType.StoredProcedure);
        return entries.ToList();
    }
}
