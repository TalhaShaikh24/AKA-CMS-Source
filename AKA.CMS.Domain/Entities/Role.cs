namespace AKA.CMS.Domain.Entities;

public sealed class Role
{
    public int RoleId { get; set; }
    public string Description { get; set; } = string.Empty;
    public DateTime CreatedDate { get; set; }
    public string CreatedBy { get; set; } = string.Empty;
    public string IpAddress { get; set; } = string.Empty;
    public bool IsActive { get; set; }
}
