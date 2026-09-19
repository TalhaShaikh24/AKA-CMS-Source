using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class CaseClosureRepository(DapperContext context) : ICaseClosureRepository
{
    public async Task<int> RequestClosureAsync(
        int caseId, string closureReason, bool symptomRemission,
        string? closureSummary, int requestedByUserId,
        int createdBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@ClosureReason", closureReason);
        parameters.Add("@SymptomRemission", symptomRemission);
        parameters.Add("@ClosureSummary", closureSummary);
        parameters.Add("@RequestedByUserId", requestedByUserId);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewClosureId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.CaseClosureRequest, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewClosureId");
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
        catch (SqlException ex) when (ex.Number == 50011)
        {
            throw new ConflictException(ex.Message);
        }
    }

    public async Task<(int CaseId, byte[] CaseRowVersion)> ApproveClosureAsync(
        int closureId, bool approve, string? rejectionReason,
        int approvedByUserId, byte[] rowVersion,
        int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@ClosureId", closureId);
        parameters.Add("@Approve", approve);
        parameters.Add("@RejectionReason", rejectionReason);
        parameters.Add("@ApprovedByUserId", approvedByUserId);
        parameters.Add("@RowVersion", rowVersion);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@CaseId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("@CaseRowVersion", dbType: DbType.Binary, size: 8, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.CaseClosureApprove, parameters,
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
    }

    public async Task<IReadOnlyList<CaseClosure>> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        var closures = await connection.QueryAsync<CaseClosure>(
            StoredProcedures.CaseClosuresGetByCase,
            new { CaseId = caseId },
            commandType: CommandType.StoredProcedure);
        return closures.ToList();
    }
}
