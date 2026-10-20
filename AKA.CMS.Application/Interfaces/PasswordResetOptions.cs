namespace AKA.CMS.Application.Interfaces;

/// <summary>Password-reset settings, bound from the "PasswordReset" configuration section.</summary>
public sealed class PasswordResetOptions
{
    public const string SectionName = "PasswordReset";

    /// <summary>How long a reset OTP stays valid, in minutes.</summary>
    public int OtpMinutes { get; set; } = 60;
}
