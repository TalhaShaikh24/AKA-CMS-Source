namespace AKA.CMS.Domain.Entities;

public sealed class ScreeningTool
{
    public string ToolCode { get; set; } = string.Empty;
    public string ToolName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int ItemCount { get; set; }
    public int MaxItemScore { get; set; }
    public int MinScore { get; set; }
    public int MaxScore { get; set; }
    public IReadOnlyList<ScreeningRiskBand> Bands { get; set; } = [];
}
