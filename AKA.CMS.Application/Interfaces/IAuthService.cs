using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IAuthService
{
    Task<LoginResponse> LoginAsync(LoginRequest request);
    Task<LoginResponse> RefreshAsync(RefreshTokenRequest request);
    Task LogoutAsync(RefreshTokenRequest request);

    /// <summary>Forgot-password step 1: e-mail a 4-digit OTP.</summary>
    Task<ForgotPasswordResponse> RequestPasswordResetAsync(ForgotPasswordRequest request, string? requestIp);

    /// <summary>Forgot-password step 2: verify the OTP against the database
    /// (does not consume it; a wrong code counts an attempt).</summary>
    Task<VerifyResetOtpResponse> VerifyResetOtpAsync(VerifyResetOtpRequest request);

    /// <summary>Forgot-password step 3: set the new password with the
    /// verified OTP (consumes it, revokes all sessions).</summary>
    Task<ResetPasswordResponse> ResetPasswordAsync(ResetPasswordRequest request);
}
