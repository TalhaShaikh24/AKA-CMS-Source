using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class SyncService(
    ISyncRepository syncRepository,
    IValidator<SyncPushRequest> pushValidator,
    IValidator<SyncAckRequest> ackValidator) : ISyncService
{
    public async Task<SyncPushResponse> PushAsync(SyncPushRequest request, int performedBy)
    {
        await pushValidator.ValidateAndThrowAsync(request);
        return await syncRepository.PushAsync(
            request.IdempotencyKey, request.DeviceId, request.EntityType,
            request.EntityId, request.Action, request.PayloadJson,
            request.BaseVersion, performedBy);
    }

    public async Task<SyncPullResponse> PullAsync(DateTime since, int page, int pageSize)
    {
        page = Math.Max(1, page);
        pageSize = Math.Clamp(pageSize, 1, 500);
        var (items, total) = await syncRepository.PullAsync(since, page, pageSize);
        var watermark = items.Count == 0 ? since : items.Max(i => i.ChangedAt);
        return new SyncPullResponse(items.ToList(), total, watermark, page, pageSize);
    }

    public async Task<SyncAckResponse> AcknowledgeAsync(SyncAckRequest request, int performedBy)
    {
        await ackValidator.ValidateAndThrowAsync(request);

        await syncRepository.AcknowledgeAsync(request.IdempotencyKey, request.DeviceId, performedBy);
        return new SyncAckResponse(request.IdempotencyKey, true);
    }
}
