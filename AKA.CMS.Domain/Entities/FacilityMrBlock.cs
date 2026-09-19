namespace AKA.CMS.Domain.Entities;

public sealed class FacilityMrBlock
{
    public int FacilityMrBlockId { get; set; }
    public int UnitCode { get; set; }
    public string MrPrefix { get; set; } = string.Empty;
    public int BlockStart { get; set; }
    public int BlockEnd { get; set; }
    public int NextSequence { get; set; }
    public bool IsPlaceholder { get; set; }
    public bool IsActive { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
