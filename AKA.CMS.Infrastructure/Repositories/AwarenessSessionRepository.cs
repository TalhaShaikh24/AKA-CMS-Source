using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class AwarenessSessionRepository(DapperContext context) : IAwarenessSessionRepository
{
    public async Task<(int SessionId, string SessionCode)> CreateAsync(
        string title, string? facilityCode, DateTime sessionDate, int? conductedBy,
        string? topic, string? targetGroup, string? venue,
        int maleCount, int femaleCount, int otherCount, string? notes,
        int createdBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@Title", title);
        parameters.Add("@FacilityCode", facilityCode);
        parameters.Add("@SessionDate", sessionDate);
        parameters.Add("@ConductedBy", conductedBy);
        parameters.Add("@Topic", topic);
        parameters.Add("@TargetGroup", targetGroup);
        parameters.Add("@Venue", venue);
        parameters.Add("@MaleCount", maleCount);
        parameters.Add("@FemaleCount", femaleCount);
        parameters.Add("@OtherCount", otherCount);
        parameters.Add("@Notes", notes);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewSessionId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("@NewSessionCode", dbType: DbType.String, size: 20, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.AwarenessSessionCreate, parameters,
                commandType: CommandType.StoredProcedure);
            return (parameters.Get<int>("@NewSessionId"), parameters.Get<string>("@NewSessionCode"));
        }
        catch (SqlException ex) when (ex.Number == 50009)
        {
            throw new ScreeningValidationException(ex.Message);
        }
    }

    public async Task<AwarenessSession?> GetByIdAsync(int sessionId)
    {
        using var connection = context.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<AwarenessSession>(
            StoredProcedures.AwarenessSessionGetById,
            new { SessionId = sessionId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IReadOnlyList<AwarenessSession>> GetListAsync(
        string? facilityCode, DateTime? fromDate, DateTime? toDate, int top)
    {
        using var connection = context.CreateConnection();
        var sessions = await connection.QueryAsync<AwarenessSession>(
            StoredProcedures.AwarenessSessionGetList,
            new { FacilityCode = facilityCode, FromDate = fromDate, ToDate = toDate, Top = top },
            commandType: CommandType.StoredProcedure);
        return sessions.ToList();
    }

    public async Task UpdateAsync(
        int sessionId, string title, string? facilityCode, DateTime sessionDate,
        string? topic, string? targetGroup, string? venue,
        int maleCount, int femaleCount, int otherCount, string? notes,
        byte[] rowVersion, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@SessionId", sessionId);
        parameters.Add("@Title", title);
        parameters.Add("@FacilityCode", facilityCode);
        parameters.Add("@SessionDate", sessionDate);
        parameters.Add("@Topic", topic);
        parameters.Add("@TargetGroup", targetGroup);
        parameters.Add("@Venue", venue);
        parameters.Add("@MaleCount", maleCount);
        parameters.Add("@FemaleCount", femaleCount);
        parameters.Add("@OtherCount", otherCount);
        parameters.Add("@Notes", notes);
        parameters.Add("@RowVersion", rowVersion);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.AwarenessSessionUpdate, parameters,
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
    }
}
