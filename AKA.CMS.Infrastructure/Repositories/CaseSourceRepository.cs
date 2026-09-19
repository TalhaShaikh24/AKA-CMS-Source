using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class CaseSourceRepository(DapperContext context) : ICaseSourceRepository
{
    public async Task<(int MappingId, bool WasNew)> RecordAsync(
        int caseId, string sourceType, int? sourceReferenceId, int createdBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@SourceType", sourceType);
        parameters.Add("@SourceReferenceId", sourceReferenceId);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewMappingId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("@WasNew", dbType: DbType.Boolean, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.CaseSourceRecord, parameters,
                commandType: CommandType.StoredProcedure);
            return (parameters.Get<int>("@NewMappingId"), parameters.Get<bool>("@WasNew"));
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            // Per Module 1 spec: a case-source record for a non-existent case is a
            // bad request (400), not a 404. The case id in the route is invalid input.
            throw new InvalidDomainValueException(ex.Message);
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

    public async Task<CaseSourceMapping?> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<CaseSourceMapping>(
            StoredProcedures.CaseSourceGetByCase,
            new { CaseId = caseId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<IReadOnlyList<CaseSourceType>> GetTypesAsync()
    {
        using var connection = context.CreateConnection();
        var types = await connection.QueryAsync<CaseSourceType>(
            StoredProcedures.CaseSourceTypeGetAll,
            commandType: CommandType.StoredProcedure);
        return types.ToList();
    }
}
