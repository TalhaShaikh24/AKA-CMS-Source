using System.Security.Cryptography;
using System.Text;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using AKA.CMS.Domain.Entities;
using FluentValidation;
using Microsoft.Extensions.Logging;

namespace AKA.CMS.Application.Services;

public sealed class AuthService(
    IAuthRepository authRepository,
    IJwtTokenService jwtTokenService,
    IPasswordHasher passwordHasher,
    IEmailSender emailSender,
    JwtOptions jwtOptions,
    SmtpOptions smtpOptions,
    PasswordResetOptions passwordResetOptions,
    ILogger<AuthService> logger,
    IValidator<LoginRequest> loginValidator,
    IValidator<RefreshTokenRequest> refreshValidator,
    IValidator<ForgotPasswordRequest> forgotPasswordValidator,
    IValidator<ResetPasswordRequest> resetPasswordValidator) : IAuthService
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

    public async Task<ForgotPasswordResponse> RequestPasswordResetAsync(ForgotPasswordRequest request, string? requestIp)
    {
        await forgotPasswordValidator.ValidateAndThrowAsync(request);

        // Never reveal whether the e-mail belongs to an account. When there is
        // no usable account we still return success and create nothing.
        var user = await authRepository.GetUserByEmailAsync(request.Email.Trim());
        if (user is not null && user.IsActive && !user.IsLocked && !string.IsNullOrWhiteSpace(user.Email))
        {
            var token = GenerateResetToken();
            var tokenHash = HashToken(token);
            var expiresAt = DateTime.UtcNow.AddMinutes(passwordResetOptions.TokenMinutes);
            await authRepository.CreatePasswordResetAsync(user.UserId, tokenHash, expiresAt, requestIp);

            var resetLink = BuildResetLink(token);
            var subject = "AKA-CMS: password reset request";
            var body = $"""
                <p>Hello {System.Net.WebUtility.HtmlEncode(user.Username)},</p>
                <p>A password reset was requested for your AKA-CMS account. Use the link below to choose a new password. The link expires in {passwordResetOptions.TokenMinutes} minutes and can be used only once.</p>
                <p><a href="{System.Net.WebUtility.HtmlEncode(resetLink)}">Reset my password</a></p>
                <p>If you did not request this, you can safely ignore this e-mail.</p>
                """;

            if (smtpOptions.IsConfigured)
            {
                await emailSender.SendAsync(user.Email, subject, body);
            }
            else
            {
                // Development fallback only: with no SMTP configured the e-mail
                // cannot be delivered, so the link is written to the log for
                // local testing. Configure the Smtp section in production.
                logger.LogWarning("Smtp is not configured; password reset link for {Email}: {ResetLink}",
                    user.Email, resetLink);
            }
        }

        return new ForgotPasswordResponse(
            "If an account exists for this e-mail address, a password reset link has been sent.");
    }

    public async Task<ResetPasswordResponse> ResetPasswordAsync(ResetPasswordRequest request)
    {
        await resetPasswordValidator.ValidateAndThrowAsync(request);

        // The stored procedure validates the token (single-use, not expired,
        // account active) and atomically applies the new password, consumes the
        // token and revokes all refresh tokens.
        var completed = await authRepository.CompletePasswordResetAsync(
            HashToken(request.Token), passwordHasher.Hash(request.NewPassword));

        if (completed is null)
            throw new UnauthorizedException("The reset token is invalid or has expired.");

        logger.LogInformation("Password reset completed for user {UserId}", completed.UserId);
        return new ResetPasswordResponse("Your password has been reset. Please sign in with the new password.");
    }

    private string BuildResetLink(string token)
    {
        var baseUrl = passwordResetOptions.ResetUrlBase.TrimEnd('/');
        return $"{baseUrl}?token={Uri.EscapeDataString(token)}";
    }

    private static string GenerateResetToken() =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
            .TrimEnd('=').Replace('+', '-').Replace('/', '_');

    private static string HashToken(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));

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
