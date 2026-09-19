using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface ISyncService
{
    Task<SyncPushResponse> PushAsync(SyncPushRequest request, int performedBy);
    Task<SyncPullResponse> PullAsync(DateTime since, int page, int pageSize);
    Task<SyncAckResponse> AcknowledgeAsync(SyncAckRequest request, int performedBy);
}
