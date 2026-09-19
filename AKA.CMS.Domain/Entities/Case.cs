namespace AKA.CMS.Domain.Entities;

public sealed class Case
{
    public int CaseId { get; set; }
    public string CaseNumber { get; set; } = string.Empty;
    public int CommunityMemberId { get; set; }
    public string? MemberName { get; set; }
    public string? MemberMrNo { get; set; }
    public string SourceType { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string? StatusName { get; set; }
    public string? CurrentStep { get; set; }
    public int? AssignedToUserId { get; set; }
    public string? AssignedToUsername { get; set; }
    public string? PriorityLevel { get; set; }
    public string? Notes { get; set; }
    public byte[] RowVersion { get; set; } = [];
    public bool IsActive { get; set; }
    public int CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public int? ModifiedBy { get; set; }
    public DateTime? ModifiedAt { get; set; }
}
