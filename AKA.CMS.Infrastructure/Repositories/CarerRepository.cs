using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class CarerRepository(DapperContext context) : ICarerRepository
{
    public async Task<int> AddAsync(
        int caseId, string fullName, string? relationship, string? phone,
        bool isPrimary, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@FullName", fullName);
        parameters.Add("@Relationship", relationship);
        parameters.Add("@Phone", phone);
        parameters.Add("@IsPrimary", isPrimary);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewCarerId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.CarerAdd, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewCarerId");
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

    public async Task UpdateAsync(
        int carerId, int caseId, string fullName, string? relationship,
        string? phone, bool isPrimary, byte[] rowVersion,
        int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CarerId", carerId);
        parameters.Add("@CaseId", caseId);
        parameters.Add("@FullName", fullName);
        parameters.Add("@Relationship", relationship);
        parameters.Add("@Phone", phone);
        parameters.Add("@IsPrimary", isPrimary);
        parameters.Add("@RowVersion", rowVersion, DbType.Binary);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.CarerUpdate, parameters,
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50009)
        {
            throw new ScreeningValidationException(ex.Message);
        }
    }

    public async Task DeactivateAsync(
        int carerId, int caseId, byte[] rowVersion,
        int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CarerId", carerId);
        parameters.Add("@CaseId", caseId);
        parameters.Add("@RowVersion", rowVersion, DbType.Binary);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.CarerDeactivate, parameters,
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException(ex.Message);
        }
    }

    public async Task<IReadOnlyList<Carer>> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        try
        {
            var carers = await connection.QueryAsync<Carer>(
                StoredProcedures.CarerGetByCase,
                new { CaseId = caseId }, commandType: CommandType.StoredProcedure);
            return carers.ToList();
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }
}
