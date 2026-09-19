using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface ILtfuService
{
    Task<EvaluateLtfuResponse> EvaluateAsync(
        int caseId, Func<string, bool> hasPermission,
        int performedBy, string ipAddress);
    Task<ReEngageLtfuResponse> ReEngageAsync(
        int caseId, ReEngageLtfuRequest request,
        Func<string, bool> hasPermission, int performedBy, string ipAddress);
    Task<LostToFollowUpDto?> GetByCaseAsync(int caseId);
}
