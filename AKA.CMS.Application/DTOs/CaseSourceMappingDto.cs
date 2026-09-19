namespace AKA.CMS.Application.DTOs;

public sealed record CaseSourceMappingDto(
    int MappingId,
    int CaseId,
    string SourceType,
    string? SourceDisplayName,
    int? SourceReferenceId,
    DateTime CreatedAt);
