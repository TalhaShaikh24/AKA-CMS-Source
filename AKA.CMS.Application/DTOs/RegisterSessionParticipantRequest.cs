namespace AKA.CMS.Application.DTOs;

public sealed record RegisterSessionParticipantRequest(
    int? CommunityMemberId,
    string? ParticipantName,
    bool Attended,
    bool ConsentedToScreening);
