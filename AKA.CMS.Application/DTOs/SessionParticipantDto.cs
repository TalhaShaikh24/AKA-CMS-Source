namespace AKA.CMS.Application.DTOs;

public sealed record SessionParticipantDto(
    int ParticipantId,
    int SessionId,
    int? CommunityMemberId,
    string? MemberName,
    string? ParticipantName,
    bool Attended,
    bool ConsentedToScreening,
    int? ScreeningId,
    DateTime CreatedAt);
