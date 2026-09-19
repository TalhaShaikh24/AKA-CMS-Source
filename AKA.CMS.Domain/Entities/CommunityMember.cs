namespace AKA.CMS.Domain.Entities;

public sealed class CommunityMember
{
    public int MemberId { get; set; }
    public string? MrNo { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string? FatherName { get; set; }
    public string? Gender { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public string? Cnic { get; set; }
    public string? Phone { get; set; }
    public string? Address { get; set; }
    public string? UnionCouncilCode { get; set; }
    public string? VillageCode { get; set; }
    public bool IsActive { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
