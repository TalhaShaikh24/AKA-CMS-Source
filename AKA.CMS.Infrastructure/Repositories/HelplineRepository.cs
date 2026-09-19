using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class HelplineRepository(DapperContext context) : IHelplineRepository
{
    public async Task<(int CallId, int? CrisisEventId, int? NotificationId)> LogCallAsync(
        string? callerName, string? callerPhone, int? caseId,
        string? indicatorsJson, string? crisisTypeCodes, string? crisisSeverity,
        string? callNotes, int handledBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CallerName", callerName);
        parameters.Add("@CallerPhone", callerPhone);
        parameters.Add("@CaseId", caseId);
        parameters.Add("@CrisisIndicatorsJson", indicatorsJson);
        parameters.Add("@CrisisTypeCodes", crisisTypeCodes);
        parameters.Add("@CrisisSeverity", crisisSeverity);
        parameters.Add("@CallNotes", callNotes);
        parameters.Add("@HandledBy", handledBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewCallId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("@NewCrisisEventId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("@NewNotificationId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.HelplineCallLog, parameters,
                commandType: CommandType.StoredProcedure);
            return (
                parameters.Get<int>("@NewCallId"),
                parameters.Get<int?>("@NewCrisisEventId"),
                parameters.Get<int?>("@NewNotificationId"));
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

    public async Task<HelplineCall> GetByIdAsync(int callId)
    {
        using var connection = context.CreateConnection();
        try
        {
            return await connection.QuerySingleAsync<HelplineCall>(
                StoredProcedures.HelplineCallGetById,
                new { HelplineCallId = callId },
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }

    public async Task<IReadOnlyList<HelplineCall>> GetListAsync(int? caseId, int top)
    {
        using var connection = context.CreateConnection();
        var calls = await connection.QueryAsync<HelplineCall>(
            StoredProcedures.HelplineCallGetList,
            new { CaseId = caseId, Top = top },
            commandType: CommandType.StoredProcedure);
        return calls.ToList();
    }
}
