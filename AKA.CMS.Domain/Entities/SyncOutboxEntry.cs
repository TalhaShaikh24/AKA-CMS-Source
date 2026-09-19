namespace AKA.CMS.Domain.Entities;

public sealed class SyncOutboxEntry
{
    public int Id { get; set; }
    public string IdempotencyKey { get; set; } = string.Empty;
    public string DeviceId { get; set; } = string.Empty;
    public string EntityType { get; set; } = string.Empty;
    public int? EntityId { get; set; }
    public string Action { get; set; } = string.Empty;
    public string PayloadJson { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public int? PerformedBy { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? ProcessedAt { get; set; }
    public DateTime? AcknowledgedAt { get; set; }
}
