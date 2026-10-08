namespace AKA.CMS.Domain.Entities;

public sealed class Facility
{
    public int FacilityId { get; set; }
    public string FacilityCode { get; set; } = string.Empty;
    public string FacilityName { get; set; } = string.Empty;
    public string? FacilityType { get; set; }
    public string? Region { get; set; }
    public string? Address { get; set; }
    public string? Phone { get; set; }
    public bool IsActive { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
