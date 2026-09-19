using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IFollowUpService
{
    Task<ScheduleFollowUpResponse> ScheduleAsync(
        ScheduleFollowUpRequest request, Func<string, bool> hasPermission,
        int performedBy, string ipAddress);
    Task<RecordFollowUpOutcomeResponse> RecordOutcomeAsync(
        int followUpId, RecordFollowUpOutcomeRequest request,
        Func<string, bool> hasPermission, int performedBy, string ipAddress);
    Task<IReadOnlyList<FollowUpDto>> GetByCaseAsync(int caseId);
}
