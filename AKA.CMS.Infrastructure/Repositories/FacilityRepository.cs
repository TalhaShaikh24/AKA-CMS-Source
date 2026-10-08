using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class FacilityRepository(DapperContext context) : IFacilityRepository
{
    public async Task<IReadOnlyList<Facility>> GetAllAsync(bool includeInactive)
    {
        using var connection = context.CreateConnection();
        var facilities = await connection.QueryAsync<Facility>(
            StoredProcedures.FacilityGetAll,
            new { IncludeInactive = includeInactive },
            commandType: CommandType.StoredProcedure);
        return facilities.ToList();
    }

    public async Task<Facility?> GetByIdAsync(int facilityId)
    {
        using var connection = context.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<Facility>(
            StoredProcedures.FacilityGetById,
            new { FacilityId = facilityId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> CreateAsync(Facility facility, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@FacilityCode", facility.FacilityCode);
        parameters.Add("@FacilityName", facility.FacilityName);
        parameters.Add("@FacilityType", facility.FacilityType);
        parameters.Add("@Region", facility.Region);
        parameters.Add("@Address", facility.Address);
        parameters.Add("@Phone", facility.Phone);
        parameters.Add("@CreatedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewFacilityId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.FacilityCreate, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewFacilityId");
        }
        catch (SqlException ex) when (ex.Number == 50011)
        {
            throw new ConflictException(ex.Message);
        }
    }

    public async Task UpdateAsync(Facility facility, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@FacilityId", facility.FacilityId);
        parameters.Add("@FacilityName", facility.FacilityName);
        parameters.Add("@FacilityType", facility.FacilityType);
        parameters.Add("@Region", facility.Region);
        parameters.Add("@Address", facility.Address);
        parameters.Add("@Phone", facility.Phone);
        parameters.Add("@IsActive", facility.IsActive);
        parameters.Add("@RowVersion", facility.RowVersion, DbType.Binary);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.FacilityUpdate, parameters,
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException($"Facility {facility.FacilityId} not found.");
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException(ex.Message);
        }
    }
}
