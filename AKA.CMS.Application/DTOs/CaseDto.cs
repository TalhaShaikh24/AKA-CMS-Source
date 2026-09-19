namespace AKA.CMS.Application.DTOs;

public sealed record CaseDto(
    int CaseId,
    string CaseNumber,
    int CommunityMemberId,
    string? MemberName,
    string? MemberMrNo,
    string SourceType,
    string Status,
    string? StatusName,
    string? CurrentStep,
    int? AssignedToUserId,
    string? AssignedToUsername,
    string? PriorityLevel,
    string? Notes,
    byte[] RowVersion,
    DateTime CreatedAt,
    DateTime? ModifiedAt);
