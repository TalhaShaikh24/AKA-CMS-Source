using System.Security.Cryptography;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using AKA.CMS.Domain.Entities;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class AuthService(
    IAuthRepository authRepository,
    IJwtTokenService jwtTokenService,
    IPasswordHasher passwordHasher,
    JwtOptions jwtOptions,
    IValidator<LoginRequest> loginValidator,
    IValidator<RefreshTokenRequest> refreshValidator) : IAuthService
{
    public async Task<LoginResponse> LoginAsync(LoginRequest request)
    {
        await loginValidator.ValidateAndThrowAsync(request);

        var user = await authRepository.GetUserByUsernameAsync(request.Username);
        if (user is null || !user.IsActive || user.IsLocked
            || user.PasswordHash is null
            || !passwordHasher.Verify(request.Password, user.PasswordHash))
            throw new UnauthorizedException("Invalid username or password.");

        return await IssueTokensAsync(user);
    }

    public async Task<LoginResponse> RefreshAsync(RefreshTokenRequest request)
    {
        await refreshValidator.ValidateAndThrowAsync(request);
        var refreshToken = request.RefreshToken;

        var stored = await authRepository.GetRefreshTokenAsync(refreshToken);
        if (stored is null || !stored.IsActive)
            throw new UnauthorizedException("Refresh token is invalid or expired.");

        var user = await authRepository.GetUserByIdAsync(stored.UserId);
        if (user is null || !user.IsActive || user.IsLocked)
            throw new UnauthorizedException("User is no longer active.");

        var response = await IssueTokensAsync(user);
        await authRepository.RevokeRefreshTokenAsync(refreshToken, response.RefreshToken);
        return response;
    }

    public async Task LogoutAsync(RefreshTokenRequest request)
    {
        await refreshValidator.ValidateAndThrowAsync(request);
        var refreshToken = request.RefreshToken;

        var stored = await authRepository.GetRefreshTokenAsync(refreshToken);
        if (stored is not null && stored.IsActive)
            await authRepository.RevokeRefreshTokenAsync(refreshToken, null);
    }

    private async Task<LoginResponse> IssueTokensAsync(User user)
    {
        var permissions = await authRepository.GetUserPermissionClaimsAsync(user.UserId);
        var accessToken = jwtTokenService.CreateAccessToken(user, permissions);
        var expiresAt = DateTime.UtcNow.AddMinutes(jwtOptions.AccessTokenMinutes);

        var refreshToken = new RefreshToken
        {
            Token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64)),
            UserId = user.UserId,
            ExpiresAt = DateTime.UtcNow.AddDays(jwtOptions.RefreshTokenDays),
            CreatedAt = DateTime.UtcNow
        };
        await authRepository.SaveRefreshTokenAsync(refreshToken);

        return new LoginResponse(
            accessToken,
            refreshToken.Token,
            expiresAt,
            new AuthUserDto(user.UserId, user.Username, user.Roles));
    }
}
