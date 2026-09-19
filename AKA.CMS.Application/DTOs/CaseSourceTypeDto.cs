namespace AKA.CMS.Application.DTOs;

public sealed record CaseSourceTypeDto(
    string SourceTypeCode,
    string DisplayName,
    string? Description,
    bool IsClientSourced,
    int SortOrder);
