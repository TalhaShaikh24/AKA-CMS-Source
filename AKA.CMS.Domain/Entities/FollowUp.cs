namespace AKA.CMS.Domain.Entities;

public sealed class FollowUp
{
    public int FollowUpId { get; set; }
    public int CaseId { get; set; }
    public DateTime ScheduledDate { get; set; }
    public DateTime? ActualDate { get; set; }
    public string FollowUpType { get; set; } = string.Empty;
    public int? AssignedToUserId { get; set; }
    public string? Notes { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? OutcomeNotes { get; set; }
    public byte[] RowVersion { get; set; } = [];
    public bool IsActive { get; set; }
    public int CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}
