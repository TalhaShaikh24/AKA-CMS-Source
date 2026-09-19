namespace AKA.CMS.Application.DTOs;

public sealed record LabelCountDto(string Label, int Count);

public sealed record HelplineSummaryDto(
    IReadOnlyList<LabelCountDto> ByType,
    IReadOnlyList<LabelCountDto> BySeverity);
