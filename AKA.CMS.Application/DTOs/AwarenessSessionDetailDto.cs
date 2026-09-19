namespace AKA.CMS.Application.DTOs;

public sealed record AwarenessSessionDetailDto(
    AwarenessSessionDto Session,
    IReadOnlyList<SessionParticipantDto> Participants);
