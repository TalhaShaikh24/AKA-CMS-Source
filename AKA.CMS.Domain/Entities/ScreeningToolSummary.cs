namespace AKA.CMS.Domain.Entities;

public sealed class ScreeningToolSummary
{
    public string ToolCode { get; set; } = string.Empty;
    public string ToolName { get; set; } = string.Empty;
    public int ScreeningCount { get; set; }
    public decimal? AvgScore { get; set; }
    public int? MinScore { get; set; }
    public int? MaxScore { get; set; }
}
