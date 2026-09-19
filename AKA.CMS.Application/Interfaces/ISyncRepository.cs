using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface ISyncRepository
{
    Task<SyncPushResponse> PushAsync(
        string idempotencyKey, string deviceId, string entityType,
        int? entityId, string action, string payloadJson,
        DateTime? baseVersion, int performedBy);
    Task<(IReadOnlyList<SyncPullItemDto> Items, long TotalCount)> PullAsync(
        DateTime since, int page, int pageSize);
    Task AcknowledgeAsync(string idempotencyKey, string deviceId, int performedBy);
}
