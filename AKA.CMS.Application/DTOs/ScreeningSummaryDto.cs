namespace AKA.CMS.Application.DTOs;

public sealed record ScreeningToolSummaryDto(
    string ToolCode,
    string ToolName,
    int ScreeningCount,
    decimal? AvgScore,
    int? MinScore,
    int? MaxScore);

public sealed record ToolRiskDistributionDto(
    string ToolCode,
    string RiskLevel,
    int ScreeningCount);

public sealed record ScreeningSummaryDto(
    IReadOnlyList<ScreeningToolSummaryDto> Tools,
    IReadOnlyList<ToolRiskDistributionDto> RiskDistribution);
