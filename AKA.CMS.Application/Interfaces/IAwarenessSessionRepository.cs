using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IAwarenessSessionRepository
{
    Task<(int SessionId, string SessionCode)> CreateAsync(
        string title, string? facilityCode, DateTime sessionDate, int? conductedBy,
        string? topic, string? targetGroup, string? venue,
        int maleCount, int femaleCount, int otherCount, string? notes,
        int createdBy, string ipAddress);
    Task<AwarenessSession?> GetByIdAsync(int sessionId);
    Task<IReadOnlyList<AwarenessSession>> GetListAsync(
        string? facilityCode, DateTime? fromDate, DateTime? toDate, int top);
    Task UpdateAsync(
        int sessionId, string title, string? facilityCode, DateTime sessionDate,
        string? topic, string? targetGroup, string? venue,
        int maleCount, int femaleCount, int otherCount, string? notes,
        byte[] rowVersion, int performedBy, string ipAddress);
}
