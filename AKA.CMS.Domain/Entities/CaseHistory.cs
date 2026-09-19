namespace AKA.CMS.Domain.Entities;

public sealed class CaseHistory
{
    public int HistoryId { get; set; }
    public int CaseId { get; set; }
    public string FromState { get; set; } = string.Empty;
    public string ToState { get; set; } = string.Empty;
    public string ActionCode { get; set; } = string.Empty;
    public string? Comment { get; set; }
    public int PerformedBy { get; set; }
    public string? PerformedByUsername { get; set; }
    public DateTime PerformedAt { get; set; }
    public string? IpAddress { get; set; }
}
