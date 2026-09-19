namespace AKA.CMS.Domain.Entities;

public sealed class CrisisType
{
    public string CrisisTypeCode { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public string DefaultSeverity { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int SortOrder { get; set; }
}
