namespace AKA.CMS.Application.DTOs;

/// <summary>Starts the forgot-password flow: e-mails a 4-digit OTP when the
/// e-mail belongs to an account. Always returns success, even when the
/// e-mail is unknown, so accounts cannot be enumerated.</summary>
public sealed record ForgotPasswordRequest(string Email);

public sealed record ForgotPasswordResponse(string Message);

/// <summary>Verifies the 4-digit OTP against the database (step 2 of the
/// forgot-password flow). A valid code is NOT consumed here — the reset
/// call consumes it — but a wrong code counts against the attempt limit.</summary>
public sealed record VerifyResetOtpRequest(string Email, string Otp);

public sealed record VerifyResetOtpResponse(string Message);

/// <summary>Completes the forgot-password flow: the verified 4-digit code
/// plus the new password. The code is single-use and expires.</summary>
public sealed record ResetPasswordRequest(string Email, string Otp, string NewPassword);

public sealed record ResetPasswordResponse(string Message);
