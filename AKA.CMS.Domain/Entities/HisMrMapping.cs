namespace AKA.CMS.Domain.Entities;

public sealed class HisMrMapping
{
    public int MappingId { get; set; }
    public int? CommunityMemberId { get; set; }
    public string MrNo { get; set; } = string.Empty;
    public bool IsDummy { get; set; }
    public int UnitCode { get; set; }
    public string? ResolvedMrNo { get; set; }
    public bool WasCreated { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
