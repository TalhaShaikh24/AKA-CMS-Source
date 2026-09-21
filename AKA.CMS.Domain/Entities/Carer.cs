namespace AKA.CMS.Domain.Entities;

/// <summary>
/// A carer (family member / guardian) engaged for a case — workflow
/// steps S5b, S20-High, S19-Mod, S19-Low, S35 ("Engage Carers").
/// </summary>
public sealed class Carer
{
    public int CarerId { get; set; }
    public int CaseId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string? Relationship { get; set; }
    public string? Phone { get; set; }
    public bool IsPrimary { get; set; }
    public bool IsActive { get; set; }
    public int CreatedBy { get; set; }
    public string? CreatedByUsername { get; set; }
    public DateTime CreatedAt { get; set; }
    public int? ModifiedBy { get; set; }
    public DateTime? ModifiedAt { get; set; }
    public string? IpAddress { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
