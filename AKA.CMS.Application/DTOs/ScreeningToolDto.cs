namespace AKA.CMS.Application.DTOs;

public sealed record ScreeningToolDto(
    string ToolCode,
    string ToolName,
    string? Description,
    int ItemCount,
    int MaxItemScore,
    int MinScore,
    int MaxScore,
    IReadOnlyList<ScreeningRiskBandDto> Bands);
