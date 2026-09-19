using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class PatientRepository(DapperContext context) : IPatientRepository
{
    public async Task<int> CreateCommunityMemberAsync(CommunityMember member, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@FullName", member.FullName);
        parameters.Add("@FatherName", member.FatherName);
        parameters.Add("@Gender", member.Gender);
        parameters.Add("@DateOfBirth", member.DateOfBirth);
        parameters.Add("@Cnic", member.Cnic);
        parameters.Add("@Phone", member.Phone);
        parameters.Add("@Address", member.Address);
        parameters.Add("@UnionCouncilCode", member.UnionCouncilCode);
        parameters.Add("@VillageCode", member.VillageCode);
        parameters.Add("@MrNo", member.MrNo);
        parameters.Add("@CreatedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewMemberId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await connection.ExecuteAsync(
            StoredProcedures.CommunityMemberCreate, parameters, commandType: CommandType.StoredProcedure);
        return parameters.Get<int>("@NewMemberId");
    }

    public async Task<CommunityMember?> GetCommunityMemberByIdAsync(int memberId)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@MemberId", memberId);
        return await connection.QuerySingleOrDefaultAsync<CommunityMember>(
            StoredProcedures.CommunityMemberGetById, parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<IReadOnlyList<PatientSearchHit>> SearchAsync(string? searchTerm)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@SearchTerm", searchTerm);
        var hits = await connection.QueryAsync<PatientSearchHit>(
            StoredProcedures.CommunityMemberSearch, parameters, commandType: CommandType.StoredProcedure);
        return hits.ToList();
    }

    public async Task<(HisMrMapping Mapping, bool WasCreated)> ResolveOrCreateMappingAsync(
        string? mrNo, int unitCode, int? communityMemberId, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@MrNo", mrNo);
        parameters.Add("@UnitCode", unitCode);
        parameters.Add("@CommunityMemberId", communityMemberId);
        parameters.Add("@CreatedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        var mapping = await connection.QuerySingleAsync<HisMrMapping>(
            StoredProcedures.HisMrMappingResolveOrCreate, parameters, commandType: CommandType.StoredProcedure);
        return (mapping, mapping.WasCreated);
    }

    public async Task<HisMrMapping> RemapToRealMrAsync(
        int mappingId, string realMrNo, byte[] rowVersion, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@MappingId", mappingId);
        parameters.Add("@RealMrNo", realMrNo);
        parameters.Add("@RowVersion", rowVersion);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        try
        {
            return await connection.QuerySingleAsync<HisMrMapping>(
                StoredProcedures.HisMrMappingRemapToRealMr, parameters, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException("The mapping was modified by another user. Reload and try again.");
        }
        catch (SqlException ex) when (ex.Number == 50003)
        {
            throw new NotFoundException($"MR mapping {mappingId} not found.");
        }
        catch (SqlException ex) when (ex.Number == 50004)
        {
            throw new ConflictException("Only dummy mappings can be remapped to a real MR.");
        }
    }

    public async Task<IReadOnlyList<FacilityMrBlock>> GetFacilityMrBlocksAsync()
    {
        using var connection = context.CreateConnection();
        var blocks = await connection.QueryAsync<FacilityMrBlock>(
            StoredProcedures.FacilityMrBlockGetAll, commandType: CommandType.StoredProcedure);
        return blocks.ToList();
    }

    public async Task UpsertFacilityMrBlockAsync(
        int unitCode, string mrPrefix, int blockStart, int blockEnd, bool isActive, int performedBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@UnitCode", unitCode);
        parameters.Add("@MrPrefix", mrPrefix);
        parameters.Add("@BlockStart", blockStart);
        parameters.Add("@BlockEnd", blockEnd);
        parameters.Add("@IsActive", isActive);
        parameters.Add("@PerformedBy", performedBy);
        await connection.ExecuteAsync(
            StoredProcedures.FacilityMrBlockUpsert, parameters, commandType: CommandType.StoredProcedure);
    }
}
