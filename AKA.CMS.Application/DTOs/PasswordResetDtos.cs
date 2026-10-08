namespace AKA.CMS.Application.DTOs;

/// <summary>Starts the forgot-password flow. Always returns success, even when
/// the e-mail is unknown, so accounts cannot be enumerated.</summary>
public sealed record ForgotPasswordRequest(string Email);

public sealed record ForgotPasswordResponse(string Message);

/// <summary>Completes the forgot-password flow with the token from the e-mail.</summary>
public sealed record ResetPasswordRequest(string Token, string NewPassword);

public sealed record ResetPasswordResponse(string Message);

/// <summary>Completes the OTP forgot-password flow with the 4-digit code
/// from the e-mail (mobile design: Forget Pass -> OTP -> Reset Pass).</summary>
public sealed record ResetPasswordOtpRequest(string Email, string Otp, string NewPassword);
