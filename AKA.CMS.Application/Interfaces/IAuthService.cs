using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IAuthService
{
    Task<LoginResponse> LoginAsync(LoginRequest request);
    Task<LoginResponse> RefreshAsync(RefreshTokenRequest request);
    Task LogoutAsync(RefreshTokenRequest request);
}
