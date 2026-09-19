using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class CrisisRepository(DapperContext context) : ICrisisRepository
{
    public async Task<(int EventId, int NotificationId)> TriggerAsync(
        int caseId, string crisisTypeCode, string severity, string triggerSource,
        string? notes, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@CrisisTypeCode", crisisTypeCode);
        parameters.Add("@Severity", severity);
        parameters.Add("@TriggerSource", triggerSource);
        parameters.Add("@Notes", notes);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewEventId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("@NewNotificationId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.CrisisEventTrigger, parameters,
                commandType: CommandType.StoredProcedure);
            return (
                parameters.Get<int>("@NewEventId"),
                parameters.Get<int>("@NewNotificationId"));
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

    public async Task<(int CaseId, byte[] CaseRowVersion)> UpdateStatusAsync(
        int crisisEventId, string newStatus, byte[] rowVersion, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CrisisEventId", crisisEventId);
        parameters.Add("@NewStatus", newStatus);
        parameters.Add("@RowVersion", rowVersion, DbType.Binary);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@CaseId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("@CaseRowVersion", dbType: DbType.Binary, size: 8, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.CrisisEventUpdateStatus, parameters,
                commandType: CommandType.StoredProcedure);
            return (
                parameters.Get<int>("@CaseId"),
                parameters.Get<byte[]>("@CaseRowVersion"));
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

    public async Task<CrisisEvent> GetByIdAsync(int crisisEventId)
    {
        using var connection = context.CreateConnection();
        try
        {
            return await connection.QuerySingleAsync<CrisisEvent>(
                StoredProcedures.CrisisEventGetById,
                new { CrisisEventId = crisisEventId },
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }

    public async Task<IReadOnlyList<CrisisEvent>> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        try
        {
            var events = await connection.QueryAsync<CrisisEvent>(
                StoredProcedures.CrisisEventGetByCase,
                new { CaseId = caseId },
                commandType: CommandType.StoredProcedure);
            return events.ToList();
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }

    public async Task<IReadOnlyList<CrisisType>> GetTypesAsync()
    {
        using var connection = context.CreateConnection();
        var types = await connection.QueryAsync<CrisisType>(
            StoredProcedures.CrisisTypeGetAll,
            commandType: CommandType.StoredProcedure);
        return types.ToList();
    }
}
