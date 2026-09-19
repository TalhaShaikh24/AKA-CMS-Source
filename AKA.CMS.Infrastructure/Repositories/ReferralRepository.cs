using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class ReferralRepository(DapperContext context) : IReferralRepository
{
    public async Task<int> CreateAsync(
        int caseId, string referredTo, DateTime? slaDueAt, string? notes,
        int createdBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@ReferredTo", referredTo);
        parameters.Add("@SlaDueAt", slaDueAt);
        parameters.Add("@Notes", notes);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewReferralId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.ReferralCreate, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewReferralId");
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

    public async Task<(int NewReferralId, string Status)> UpdateStatusAsync(
        int referralId, string newStatus, string? rejectionReason,
        byte[] rowVersion, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@ReferralId", referralId);
        parameters.Add("@NewStatus", newStatus);
        parameters.Add("@RejectionReason", rejectionReason);
        parameters.Add("@RowVersion", rowVersion, DbType.Binary);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewReferralId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.ReferralUpdateStatus, parameters,
                commandType: CommandType.StoredProcedure);
            return (parameters.Get<int?>("@NewReferralId") ?? 0, newStatus.ToUpperInvariant());
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

    public async Task<IReadOnlyList<Referral>> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        try
        {
            var referrals = await connection.QueryAsync<Referral>(
                StoredProcedures.ReferralGetByCase,
                new { CaseId = caseId }, commandType: CommandType.StoredProcedure);
            return referrals.ToList();
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }

    public async Task<Referral> GetByIdAsync(int referralId)
    {
        using var connection = context.CreateConnection();
        try
        {
            return await connection.QuerySingleAsync<Referral>(
                StoredProcedures.ReferralGetById,
                new { ReferralId = referralId }, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }
}
