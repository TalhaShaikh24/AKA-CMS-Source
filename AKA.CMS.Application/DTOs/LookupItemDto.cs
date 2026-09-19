namespace AKA.CMS.Application.DTOs;

public sealed record LookupItemDto(
    string Code,
    string Name,
    string? Description,
    int SortOrder,
    bool IsActive,
    string? Extra);
