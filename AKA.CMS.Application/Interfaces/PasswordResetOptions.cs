namespace AKA.CMS.Application.Interfaces;

/// <summary>Password-reset settings, bound from the "PasswordReset" configuration section.</summary>
public sealed class PasswordResetOptions
{
    public const string SectionName = "PasswordReset";

    /// <summary>Base URL the reset token is appended to, e.g.
    /// https://app.example.com/reset-password — the e-mail links to {ResetUrlBase}?token=...</summary>
    public string ResetUrlBase { get; set; } = string.Empty;

    /// <summary>How long a reset token stays valid, in minutes.</summary>
    public int TokenMinutes { get; set; } = 60;
}
