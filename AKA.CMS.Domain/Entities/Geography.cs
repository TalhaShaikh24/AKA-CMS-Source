namespace AKA.CMS.Domain.Entities;

public sealed class Region
{
    public int RegionId { get; set; }
    public string RegionName { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public byte[] RowVersion { get; set; } = [];
}

public sealed class LocalCouncil
{
    public int CouncilId { get; set; }
    public int? RegionId { get; set; }
    public string? RegionName { get; set; }
    public string CouncilName { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public byte[] RowVersion { get; set; } = [];
}

public sealed class Village
{
    public int VillageId { get; set; }
    public int? CouncilId { get; set; }
    public string? CouncilName { get; set; }
    public string VillageName { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
