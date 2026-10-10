using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class GeographyRepository(DapperContext context) : IGeographyRepository
{
    public async Task<IReadOnlyList<Region>> GetRegionsAsync(bool includeInactive)
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<Region>(
            StoredProcedures.RegionGetAll,
            new { IncludeInactive = includeInactive },
            commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    public async Task<Region?> GetRegionByIdAsync(int regionId)
    {
        using var connection = context.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<Region>(
            StoredProcedures.RegionGetById,
            new { RegionId = regionId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> CreateRegionAsync(Region region, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@RegionName", region.RegionName);
        parameters.Add("@CreatedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewRegionId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.RegionCreate, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewRegionId");
        }
        catch (SqlException ex) when (ex.Number == 50011)
        {
            throw new ConflictException(ex.Message);
        }
    }

    public async Task UpdateRegionAsync(Region region, int performedBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@RegionId", region.RegionId);
        parameters.Add("@RegionName", region.RegionName);
        parameters.Add("@IsActive", region.IsActive);
        parameters.Add("@RowVersion", region.RowVersion, DbType.Binary);
        parameters.Add("@PerformedBy", performedBy);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.RegionUpdate, parameters,
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException($"Region {region.RegionId} not found.");
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50011)
        {
            throw new ConflictException(ex.Message);
        }
    }

    public async Task<IReadOnlyList<LocalCouncil>> GetLocalCouncilsAsync(int? regionId, bool includeInactive)
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<LocalCouncil>(
            StoredProcedures.LocalCouncilGetAll,
            new { RegionId = regionId, IncludeInactive = includeInactive },
            commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    public async Task<LocalCouncil?> GetLocalCouncilByIdAsync(int councilId)
    {
        using var connection = context.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<LocalCouncil>(
            StoredProcedures.LocalCouncilGetById,
            new { CouncilId = councilId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> CreateLocalCouncilAsync(LocalCouncil council, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@RegionId", council.RegionId);
        parameters.Add("@CouncilName", council.CouncilName);
        parameters.Add("@CreatedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewCouncilId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.LocalCouncilCreate, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewCouncilId");
        }
        catch (SqlException ex) when (ex.Number == 50011)
        {
            throw new ConflictException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }

    public async Task UpdateLocalCouncilAsync(LocalCouncil council, int performedBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CouncilId", council.CouncilId);
        parameters.Add("@RegionId", council.RegionId);
        parameters.Add("@CouncilName", council.CouncilName);
        parameters.Add("@IsActive", council.IsActive);
        parameters.Add("@RowVersion", council.RowVersion, DbType.Binary);
        parameters.Add("@PerformedBy", performedBy);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.LocalCouncilUpdate, parameters,
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException($"Local council {council.CouncilId} not found.");
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50011)
        {
            throw new ConflictException(ex.Message);
        }
    }

    public async Task<IReadOnlyList<Village>> GetVillagesAsync(int? councilId, bool includeInactive)
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<Village>(
            StoredProcedures.VillageGetAll,
            new { CouncilId = councilId, IncludeInactive = includeInactive },
            commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    public async Task<Village?> GetVillageByIdAsync(int villageId)
    {
        using var connection = context.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<Village>(
            StoredProcedures.VillageGetById,
            new { VillageId = villageId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> CreateVillageAsync(Village village, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CouncilId", village.CouncilId);
        parameters.Add("@VillageName", village.VillageName);
        parameters.Add("@CreatedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewVillageId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.VillageCreate, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewVillageId");
        }
        catch (SqlException ex) when (ex.Number == 50011)
        {
            throw new ConflictException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }

    public async Task UpdateVillageAsync(Village village, int performedBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@VillageId", village.VillageId);
        parameters.Add("@CouncilId", village.CouncilId);
        parameters.Add("@VillageName", village.VillageName);
        parameters.Add("@IsActive", village.IsActive);
        parameters.Add("@RowVersion", village.RowVersion, DbType.Binary);
        parameters.Add("@PerformedBy", performedBy);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.VillageUpdate, parameters,
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException($"Village {village.VillageId} not found.");
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50011)
        {
            throw new ConflictException(ex.Message);
        }
    }
}
