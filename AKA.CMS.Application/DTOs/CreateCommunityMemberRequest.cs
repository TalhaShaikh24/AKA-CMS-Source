namespace AKA.CMS.Application.DTOs;

public sealed record CreateCommunityMemberRequest(
    string FullName,
    string? FatherName,
    string? Gender,
    DateTime? DateOfBirth,
    string? Cnic,
    string? Phone,
    string? Address,
    string? UnionCouncilCode,
    string? VillageCode,
    string? MrNo);
