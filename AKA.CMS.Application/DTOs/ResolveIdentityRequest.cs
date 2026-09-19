namespace AKA.CMS.Application.DTOs;

public sealed record ResolveIdentityRequest(
    string? MrNo,
    int UnitCode,
    int? CommunityMemberId,
    string? FullName,
    string? Gender,
    string? Phone,
    string? Cnic);
