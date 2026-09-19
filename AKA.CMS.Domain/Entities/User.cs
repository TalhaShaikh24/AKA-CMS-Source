namespace AKA.CMS.Domain.Entities;

public sealed class User
{
    public int UserId { get; set; }
    public string Username { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string CreatedBy { get; set; } = string.Empty;
    public DateTime CreatedDate { get; set; }
    public string IpAddress { get; set; } = string.Empty;
    public bool IsLocked { get; set; }
    public bool IsActive { get; set; }
    public bool IsAdUser { get; set; }
    public bool IsAdmin { get; set; }
    public string? PasswordHash { get; set; }
    public List<string> Roles { get; set; } = new();
}
