namespace AKA.CMS.Domain.Entities;

public sealed class CaseListItem
{
    public int CaseId { get; set; }
    public string? CaseNumber { get; set; }
    public int? CommunityMemberId { get; set; }
    public string? MemberName { get; set; }
    public string? MemberMrNo { get; set; }
    public int? MemberAge { get; set; }
    public string? MemberGender { get; set; }
    public string? MemberVillage { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? StatusName { get; set; }
    public string? PriorityLevel { get; set; }
    public DateTime CreatedAt { get; set; }
    public int TotalCount { get; set; }
}
