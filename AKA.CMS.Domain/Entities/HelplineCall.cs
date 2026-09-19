namespace AKA.CMS.Domain.Entities;

public sealed class HelplineCall
{
    public int HelplineCallId { get; set; }
    public string? CallerName { get; set; }
    public string? CallerPhone { get; set; }
    public int? CaseId { get; set; }
    public string? CrisisIndicatorsJson { get; set; }
    public string? CrisisTypeCodes { get; set; }
    public string? CrisisSeverity { get; set; }
    public string? CallNotes { get; set; }
    public int HandledBy { get; set; }
    public string? HandledByUsername { get; set; }
    public DateTime CallStartedAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
