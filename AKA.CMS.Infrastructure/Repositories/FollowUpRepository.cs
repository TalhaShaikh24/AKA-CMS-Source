using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class FollowUpRepository(DapperContext context) : IFollowUpRepository
{
    public async Task<int> ScheduleAsync(
        int caseId, DateTime scheduledDate, string followUpType,
        int? assignedToUserId, string? notes,
        int createdBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@ScheduledDate", scheduledDate);
        parameters.Add("@FollowUpType", followUpType);
        parameters.Add("@AssignedToUserId", assignedToUserId);
        parameters.Add("@Notes", notes);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewFollowUpId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.FollowUpSchedule, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewFollowUpId");
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

    public async Task<(int CaseId, byte[] CaseRowVersion)> RecordOutcomeAsync(
        int followUpId, string outcome, string? outcomeNotes, DateTime? actualDate,
        byte[] rowVersion, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@FollowUpId", followUpId);
        parameters.Add("@Outcome", outcome);
        parameters.Add("@OutcomeNotes", outcomeNotes);
        parameters.Add("@ActualDate", actualDate);
        parameters.Add("@RowVersion", rowVersion);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@CaseId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("@CaseRowVersion", dbType: DbType.Binary, size: 8, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.FollowUpRecordOutcome, parameters,
                commandType: CommandType.StoredProcedure);
            return (
                parameters.Get<int>("@CaseId"),
                parameters.Get<byte[]>("@CaseRowVersion") ?? Array.Empty<byte>());
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

    public async Task<(bool Declared, int LtfuId)> FlagLtfuAsync(
        int caseId, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@Declared", dbType: DbType.Boolean, direction: ParameterDirection.Output);
        parameters.Add("@LtfuId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.LostToFollowUpFlag, parameters,
                commandType: CommandType.StoredProcedure);
            return (
                parameters.Get<bool>("@Declared"),
                parameters.Get<int>("@LtfuId"));
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }

    public async Task<byte[]> ReEngageLtfuAsync(
        int caseId, string reEngagementNotes, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@ReEngagementNotes", reEngagementNotes);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@CaseRowVersion", dbType: DbType.Binary, size: 8, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.LostToFollowUpReEngage, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<byte[]>("@CaseRowVersion");
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50009)
        {
            throw new ScreeningValidationException(ex.Message);
        }
    }

    public async Task<IReadOnlyList<FollowUp>> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        var followUps = await connection.QueryAsync<FollowUp>(
            StoredProcedures.FollowUpsGetByCase,
            new { CaseId = caseId },
            commandType: CommandType.StoredProcedure);
        return followUps.ToList();
    }

    public async Task<LostToFollowUp?> GetLtfuByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<LostToFollowUp>(
            StoredProcedures.LostToFollowUpGetByCase,
            new { CaseId = caseId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IReadOnlyList<DueFollowUp>> GetDueAsync()
    {
        using var connection = context.CreateConnection();
        var due = await connection.QueryAsync<DueFollowUp>(
            StoredProcedures.FollowUpGetDue,
            commandType: CommandType.StoredProcedure);
        return due.ToList();
    }
}
