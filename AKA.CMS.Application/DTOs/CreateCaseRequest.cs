namespace AKA.CMS.Application.DTOs;

public sealed record CreateCaseRequest(
    int CommunityMemberId,
    string SourceType,
    string? PriorityLevel,
    string? Notes,
    int? SourceReferenceId = null);
