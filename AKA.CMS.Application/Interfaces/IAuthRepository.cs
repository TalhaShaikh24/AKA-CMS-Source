using AKA.CMS.Application.DTOs;
using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IAuthRepository
{
    Task<User?> GetUserByUsernameAsync(string username);
    Task<User?> GetUserByIdAsync(int userId);
    Task<IReadOnlyList<string>> GetUserPermissionClaimsAsync(int userId);
    Task SaveRefreshTokenAsync(RefreshToken token);
    Task<RefreshToken?> GetRefreshTokenAsync(string token);
    Task RevokeRefreshTokenAsync(string token, string? replacedByToken);
    Task<IReadOnlyList<ControllerAction>> GetAllPermissionsAsync();
}
