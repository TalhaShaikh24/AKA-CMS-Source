using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IFollowUpRepository
{
    Task<int> ScheduleAsync(
        int caseId, DateTime scheduledDate, string followUpType,
        int? assignedToUserId, string? notes,
        int createdBy, string ipAddress);
    Task<(int CaseId, byte[] CaseRowVersion)> RecordOutcomeAsync(
        int followUpId, string outcome, string? outcomeNotes, DateTime? actualDate,
        byte[] rowVersion, int performedBy, string ipAddress);
    Task<(bool Declared, int LtfuId)> FlagLtfuAsync(
        int caseId, int performedBy, string ipAddress);
    Task<byte[]> ReEngageLtfuAsync(
        int caseId, string reEngagementNotes, int performedBy, string ipAddress);
    Task<IReadOnlyList<FollowUp>> GetByCaseAsync(int caseId);
    Task<LostToFollowUp?> GetLtfuByCaseAsync(int caseId);
    Task<IReadOnlyList<DueFollowUp>> GetDueAsync();
}
