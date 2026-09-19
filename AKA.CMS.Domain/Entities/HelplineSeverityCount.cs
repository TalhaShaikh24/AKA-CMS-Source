namespace AKA.CMS.Domain.Entities;

public sealed class HelplineSeverityCount
{
    public string Severity { get; set; } = string.Empty;
    public int CallCount { get; set; }
}
