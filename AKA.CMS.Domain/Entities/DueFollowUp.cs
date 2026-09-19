namespace AKA.CMS.Domain.Entities;

public sealed class DueFollowUp
{
    public int CaseId { get; set; }
    public string CaseNumber { get; set; } = string.Empty;
    public string? PriorityLevel { get; set; }
    public string CaseStatus { get; set; } = string.Empty;
    public DateTime LastContactDate { get; set; }
    public int DaysSinceContact { get; set; }
    public int FrequencyDays { get; set; }
}
