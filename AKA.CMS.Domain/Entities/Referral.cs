namespace AKA.CMS.Domain.Entities;

public sealed class Referral
{
    public int ReferralId { get; set; }
    public string ReferralNumber { get; set; } = string.Empty;
    public int CaseId { get; set; }
    public string? CaseNumber { get; set; }
    public string ReferredTo { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string? RejectionReason { get; set; }
    public int? ParentReferralId { get; set; }
    public string? ParentReferralNumber { get; set; }
    public DateTime SlaDueAt { get; set; }
    public string? Notes { get; set; }
    public int CreatedBy { get; set; }
    public string? CreatedByUsername { get; set; }
    public DateTime CreatedAt { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
