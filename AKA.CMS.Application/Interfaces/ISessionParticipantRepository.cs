using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface ISessionParticipantRepository
{
    Task<(int ParticipantId, bool WasNew)> RegisterAsync(
        int sessionId, int? communityMemberId, string? participantName,
        bool attended, bool consentedToScreening, int createdBy, string ipAddress);
    Task<IReadOnlyList<SessionParticipant>> GetListAsync(int sessionId);
    Task LinkScreeningAsync(int participantId, int screeningId, int performedBy, string ipAddress);
}
