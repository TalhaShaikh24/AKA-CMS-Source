namespace AKA.CMS.Domain.Entities;

public sealed class CaseClosure
{
    public int ClosureId { get; set; }
    public int CaseId { get; set; }
    public string ClosureReason { get; set; } = string.Empty;
    public bool SymptomRemission { get; set; }
    public string? ClosureSummary { get; set; }
    public string ApprovalStatus { get; set; } = string.Empty;
    public int RequestedByUserId { get; set; }
    public DateTime RequestedAt { get; set; }
    public int? ApprovedByUserId { get; set; }
    public DateTime? ApprovedAt { get; set; }
    public string? RejectionReason { get; set; }
    public byte[] RowVersion { get; set; } = [];
    public bool IsActive { get; set; }
    public int CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}
