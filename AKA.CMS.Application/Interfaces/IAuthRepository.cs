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
    Task CreatePasswordResetOtpAsync(int userId, string otpHash, DateTime expiresAtUtc, string? requestIp);

    /// <summary>Checks an OTP without consuming it (wrong codes count an
    /// attempt). Returns true when the code is valid.</summary>
    Task<bool> VerifyPasswordResetOtpAsync(int userId, string otpHash);
    Task<PasswordResetToken?> CompletePasswordResetOtpAsync(int userId, string otpHash, string passwordHash);
}
