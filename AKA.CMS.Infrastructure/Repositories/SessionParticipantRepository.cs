using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class SessionParticipantRepository(DapperContext context) : ISessionParticipantRepository
{
    public async Task<(int ParticipantId, bool WasNew)> RegisterAsync(
        int sessionId, int? communityMemberId, string? participantName,
        bool attended, bool consentedToScreening, int createdBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@SessionId", sessionId);
        parameters.Add("@CommunityMemberId", communityMemberId);
        parameters.Add("@ParticipantName", participantName);
        parameters.Add("@Attended", attended);
        parameters.Add("@ConsentedToScreening", consentedToScreening);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewParticipantId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("@WasNew", dbType: DbType.Boolean, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.SessionParticipantRegister, parameters,
                commandType: CommandType.StoredProcedure);
            return (parameters.Get<int>("@NewParticipantId"), parameters.Get<bool>("@WasNew"));
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

    public async Task<IReadOnlyList<SessionParticipant>> GetListAsync(int sessionId)
    {
        using var connection = context.CreateConnection();
        var participants = await connection.QueryAsync<SessionParticipant>(
            StoredProcedures.SessionParticipantGetList,
            new { SessionId = sessionId },
            commandType: CommandType.StoredProcedure);
        return participants.ToList();
    }

    public async Task LinkScreeningAsync(int participantId, int screeningId, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.SessionParticipantLinkScreening,
                new { ParticipantId = participantId, ScreeningId = screeningId, PerformedBy = performedBy, IpAddress = ipAddress },
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }
}
