namespace AKA.CMS.Domain.Entities;

public sealed class CaseAssignmentQueueEntry
{
    public int QueueId { get; set; }
    public int CaseId { get; set; }
    public string? CaseNumber { get; set; }
    public string RiskCategory { get; set; } = string.Empty;
    public DateTime SlaDueAt { get; set; }
    public int? AssignedToUserId { get; set; }
    public string? AssignedToUsername { get; set; }
    public string Status { get; set; } = string.Empty;
    public int EnqueuedBy { get; set; }
    public string? EnqueuedByUsername { get; set; }
    public DateTime EnqueuedAt { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
