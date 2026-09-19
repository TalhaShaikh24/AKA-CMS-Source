using AKA.CMS.Application.DTOs;
using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IAuthRepository
{
    Task<User?> GetUserByUsernameAsync(string username);
    Task<User?> GetUserByIdAsync(int userId);
    Task<User?> GetUserByEmailAsync(string email);
    Task<IReadOnlyList<string>> GetUserPermissionClaimsAsync(int userId);
    Task SaveRefreshTokenAsync(RefreshToken token);
    Task<RefreshToken?> GetRefreshTokenAsync(string token);
    Task RevokeRefreshTokenAsync(string token, string? replacedByToken);
    Task<IReadOnlyList<ControllerAction>> GetAllPermissionsAsync();
    Task CreatePasswordResetAsync(int userId, string tokenHash, DateTime expiresAtUtc, string? requestIp);
    Task<PasswordResetToken?> CompletePasswordResetAsync(string tokenHash, string passwordHash);
}
