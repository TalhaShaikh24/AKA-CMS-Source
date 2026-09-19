namespace AKA.CMS.Domain.Entities;

public sealed class CrisisEvent
{
    public int CrisisEventId { get; set; }
    public int CaseId { get; set; }
    public string CrisisTypeCode { get; set; } = string.Empty;
    public string? CrisisTypeName { get; set; }
    public string Severity { get; set; } = string.Empty;
    public string TriggerSource { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string? Notes { get; set; }
    public int CreatedBy { get; set; }
    public string? CreatedByUsername { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
