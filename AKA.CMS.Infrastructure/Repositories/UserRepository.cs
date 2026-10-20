using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class UserRepository(DapperContext context) : IUserRepository
{
    public async Task<User?> GetByIdAsync(int userId)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@UserId", userId);
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.UserGetById, parameters, commandType: CommandType.StoredProcedure);
        var user = await multi.ReadSingleOrDefaultAsync<User>();
        if (user is null) return null;
        user.Roles = (await multi.ReadAsync<string>()).ToList();
        return user;
    }

    public async Task<IReadOnlyList<User>> GetAllAsync()
    {
        using var connection = context.CreateConnection();
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.UserGetAll, commandType: CommandType.StoredProcedure);
        var users = (await multi.ReadAsync<User>()).ToList();
        var roles = (await multi.ReadAsync<UserRoleRow>()).ToList();
        foreach (var user in users)
            user.Roles = roles.Where(r => r.UserId == user.UserId).Select(r => r.RoleName).ToList();
        return users;
    }

    public async Task<int> CreateAsync(User user, string? passwordHash, int performedBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@Username", user.Username);
        parameters.Add("@PasswordHash", passwordHash);
        parameters.Add("@CreatedBy", performedBy);
        parameters.Add("@Email", user.Email);
        parameters.Add("@UserType", string.IsNullOrWhiteSpace(user.UserType) ? "System" : user.UserType);
        parameters.Add("@NewUserId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await connection.ExecuteAsync(
            StoredProcedures.UserCreate, parameters, commandType: CommandType.StoredProcedure);
        return parameters.Get<int>("@NewUserId");
    }

    public async Task UpdateAsync(int userId, bool? isActive, bool? isLocked, string? passwordHash, string? email, int performedBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@UserId", userId);
        parameters.Add("@IsActive", isActive);
        parameters.Add("@IsLocked", isLocked);
        parameters.Add("@PasswordHash", passwordHash);
        parameters.Add("@Email", email);
        parameters.Add("@PerformedBy", performedBy);
        await connection.ExecuteAsync(
            StoredProcedures.UserUpdate, parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task AssignRoleAsync(int userId, int roleId, int unitCode, string createdBy, int performedBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@UserId", userId);
        parameters.Add("@RoleId", roleId);
        parameters.Add("@UnitCode", unitCode);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@PerformedBy", performedBy);
        await connection.ExecuteAsync(
            StoredProcedures.UserAssignRole, parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task RemoveRoleAsync(int userId, int roleId, int performedBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@UserId", userId);
        parameters.Add("@RoleId", roleId);
        parameters.Add("@PerformedBy", performedBy);
        await connection.ExecuteAsync(
            StoredProcedures.UserRemoveRole, parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<IReadOnlyList<string>> GetRolesAsync(int userId)
    {
        var user = await GetByIdAsync(userId);
        return user?.Roles ?? [];
    }

    public async Task<IReadOnlyList<AKA.CMS.Application.DTOs.AdDirectoryUserDto>> GetAdDirectoryAsync()
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<AKA.CMS.Application.DTOs.AdDirectoryUserDto>(
            StoredProcedures.AdDirectoryGetAll, commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    private sealed class UserRoleRow
    {
        public int UserId { get; set; }
        public string RoleName { get; set; } = string.Empty;
    }
}
