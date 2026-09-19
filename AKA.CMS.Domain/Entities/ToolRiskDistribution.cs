namespace AKA.CMS.Domain.Entities;

public sealed class ToolRiskDistribution
{
    public string ToolCode { get; set; } = string.Empty;
    public string RiskLevel { get; set; } = string.Empty;
    public int ScreeningCount { get; set; }
}
