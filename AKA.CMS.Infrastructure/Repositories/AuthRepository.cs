using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class AuthRepository(DapperContext context) : IAuthRepository
{
    public async Task<User?> GetUserByUsernameAsync(string username)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@Username", username);
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.AuthGetUserByUsername, parameters, commandType: CommandType.StoredProcedure);
        var user = await multi.ReadSingleOrDefaultAsync<User>();
        if (user is null) return null;
        user.Roles = (await multi.ReadAsync<string>()).ToList();
        return user;
    }

    public async Task<User?> GetUserByIdAsync(int userId)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@UserId", userId);
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.AuthGetUserById, parameters, commandType: CommandType.StoredProcedure);
        var user = await multi.ReadSingleOrDefaultAsync<User>();
        if (user is null) return null;
        user.Roles = (await multi.ReadAsync<string>()).ToList();
        return user;
    }

    public async Task<IReadOnlyList<string>> GetUserPermissionClaimsAsync(int userId)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@UserId", userId);
        var permissions = await connection.QueryAsync<ControllerAction>(
            StoredProcedures.AuthGetUserPermissions, parameters, commandType: CommandType.StoredProcedure);
        return permissions.Select(p => p.ClaimValue).Distinct().ToList();
    }

    public async Task<IReadOnlyList<ControllerAction>> GetAllPermissionsAsync()
    {
        using var connection = context.CreateConnection();
        var permissions = await connection.QueryAsync<ControllerAction>(
            StoredProcedures.AuthGetAllPermissions, commandType: CommandType.StoredProcedure);
        return permissions.ToList();
    }

    public async Task SaveRefreshTokenAsync(RefreshToken token)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@Token", token.Token);
        parameters.Add("@UserId", token.UserId);
        parameters.Add("@ExpiresAt", token.ExpiresAt);
        await connection.ExecuteAsync(
            StoredProcedures.AuthSaveRefreshToken, parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<RefreshToken?> GetRefreshTokenAsync(string token)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@Token", token);
        return await connection.QuerySingleOrDefaultAsync<RefreshToken>(
            StoredProcedures.AuthGetRefreshToken, parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task RevokeRefreshTokenAsync(string token, string? replacedByToken)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@Token", token);
        parameters.Add("@ReplacedByToken", replacedByToken);
        await connection.ExecuteAsync(
            StoredProcedures.AuthRevokeRefreshToken, parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<User?> GetUserByEmailAsync(string email)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@Email", email);
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.AuthGetUserByEmail, parameters, commandType: CommandType.StoredProcedure);
        var user = await multi.ReadSingleOrDefaultAsync<User>();
        if (user is null) return null;
        user.Roles = (await multi.ReadAsync<string>()).ToList();
        return user;
    }

    public async Task CreatePasswordResetAsync(int userId, string tokenHash, DateTime expiresAtUtc, string? requestIp)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@UserId", userId);
        parameters.Add("@TokenHash", tokenHash);
        parameters.Add("@ExpiresAtUtc", expiresAtUtc);
        parameters.Add("@RequestIp", requestIp);
        await connection.ExecuteAsync(
            StoredProcedures.PasswordResetCreate, parameters, commandType: CommandType.StoredProcedure);
    }

    public async Task<PasswordResetToken?> CompletePasswordResetAsync(string tokenHash, string passwordHash)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@TokenHash", tokenHash);
        parameters.Add("@PasswordHash", passwordHash);
        return await connection.QuerySingleOrDefaultAsync<PasswordResetToken>(
            StoredProcedures.PasswordResetComplete, parameters, commandType: CommandType.StoredProcedure);
    }
}
