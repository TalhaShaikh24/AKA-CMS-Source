namespace AKA.CMS.Domain.Entities;

public sealed class LostToFollowUp
{
    public int LtfuId { get; set; }
    public int CaseId { get; set; }
    public int MissedCount { get; set; }
    public DateTime? LastContactDate { get; set; }
    public DateTime? LtfuDeclaredDate { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? ReEngagementNotes { get; set; }
    public byte[] RowVersion { get; set; } = [];
    public bool IsActive { get; set; }
    public int CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}
