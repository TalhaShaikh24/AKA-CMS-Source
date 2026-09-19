using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class ScreeningRepository(DapperContext context) : IScreeningRepository
{
    public async Task<IReadOnlyList<ScreeningTool>> GetToolsAsync()
    {
        using var connection = context.CreateConnection();
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.ScreeningToolGetAll, commandType: CommandType.StoredProcedure);

        var tools = (await multi.ReadAsync<ScreeningTool>()).ToList();
        var bands = (await multi.ReadAsync<ScreeningRiskBand>()).ToList();

        foreach (var tool in tools)
        {
            tool.Bands = bands
                .Where(b => b.ToolCode == tool.ToolCode)
                .OrderBy(b => b.SortOrder)
                .ToList();
        }

        return tools;
    }

    public async Task<Screening> SubmitAsync(
        int caseId, string toolCode, string itemScoresJson,
        int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@ToolCode", toolCode);
        parameters.Add("@ItemScoresJson", itemScoresJson);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewScreeningId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("@MentalHealthSynced", dbType: DbType.Boolean, direction: ParameterDirection.Output);
        parameters.Add("@MentalHealthCode", dbType: DbType.String, size: 20, direction: ParameterDirection.Output);
        try
        {
            return await connection.QuerySingleAsync<Screening>(
                StoredProcedures.ScreeningSubmit, parameters, commandType: CommandType.StoredProcedure);
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

    public async Task<IReadOnlyList<Screening>> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        try
        {
            var screenings = await connection.QueryAsync<Screening>(
                StoredProcedures.ScreeningGetByCase, parameters,
                commandType: CommandType.StoredProcedure);
            return screenings.ToList();
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException($"Case {caseId} not found.");
        }
    }
}
