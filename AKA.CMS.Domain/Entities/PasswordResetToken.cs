namespace AKA.CMS.Domain.Entities;

/// <summary>Result of completing a password reset: the user whose password was changed.</summary>
public sealed class PasswordResetToken
{
    public int UserId { get; set; }
    public string Username { get; set; } = string.Empty;
    public string? Email { get; set; }
}
