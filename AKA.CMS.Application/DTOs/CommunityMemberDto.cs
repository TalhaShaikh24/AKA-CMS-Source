namespace AKA.CMS.Application.DTOs;

public sealed record CommunityMemberDto(
    int MemberId,
    string? MrNo,
    string FullName,
    string? FatherName,
    string? Gender,
    DateTime? DateOfBirth,
    string? Cnic,
    string? Phone,
    string? Address,
    bool IsActive);
