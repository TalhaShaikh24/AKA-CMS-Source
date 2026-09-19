namespace AKA.CMS.Domain.Entities;

public sealed class AuditLog
{
    public long Id { get; set; }
    public string TableName { get; set; } = string.Empty;
    public string RecordId { get; set; } = string.Empty;
    public string Action { get; set; } = string.Empty;
    public int? PerformedBy { get; set; }
    public DateTime PerformedAt { get; set; }
    public string? Details { get; set; }
}
