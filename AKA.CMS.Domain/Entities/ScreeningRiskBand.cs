namespace AKA.CMS.Domain.Entities;

public sealed class ScreeningRiskBand
{
    public string ToolCode { get; set; } = string.Empty;
    public string BandCode { get; set; } = string.Empty;
    public string BandName { get; set; } = string.Empty;
    public int MinScore { get; set; }
    public int MaxScore { get; set; }
    public int SortOrder { get; set; }
}
