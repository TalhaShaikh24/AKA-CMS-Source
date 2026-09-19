namespace AKA.CMS.Application.DTOs;

public sealed record RegisterSessionParticipantResponse(
    SessionParticipantDto Participant,
    bool WasNew);
