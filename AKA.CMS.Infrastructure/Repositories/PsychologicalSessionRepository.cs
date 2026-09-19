using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class PsychologicalSessionRepository(DapperContext context) : IPsychologicalSessionRepository
{
    public async Task<int> RecordAsync(
        int planId, int caseId, int? therapistUserId, DateTime sessionDate,
        string modalityCode, int? durationMinutes, string? sessionNotes,
        string? outcomeNotes, DateTime? nextSessionDate,
        int createdBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@PlanId", planId);
        parameters.Add("@CaseId", caseId);
        parameters.Add("@TherapistUserId", therapistUserId);
        parameters.Add("@SessionDate", sessionDate);
        parameters.Add("@ModalityCode", modalityCode);
        parameters.Add("@DurationMinutes", durationMinutes);
        parameters.Add("@SessionNotes", sessionNotes);
        parameters.Add("@OutcomeNotes", outcomeNotes);
        parameters.Add("@NextSessionDate", nextSessionDate);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewSessionId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.PsychologicalSessionRecord, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewSessionId");
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

    public async Task<IReadOnlyList<PsychologicalSession>> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        var sessions = await connection.QueryAsync<PsychologicalSession>(
            StoredProcedures.PsychologicalSessionGetByCase,
            new { CaseId = caseId },
            commandType: CommandType.StoredProcedure);
        return sessions.ToList();
    }
}
