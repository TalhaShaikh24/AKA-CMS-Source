using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IPsychologicalSessionRepository
{
    Task<int> RecordAsync(
        int planId, int caseId, int? therapistUserId, DateTime sessionDate,
        string modalityCode, int? durationMinutes, string? sessionNotes,
        string? outcomeNotes, DateTime? nextSessionDate,
        int createdBy, string ipAddress);
    Task<IReadOnlyList<PsychologicalSession>> GetByCaseAsync(int caseId);
}
