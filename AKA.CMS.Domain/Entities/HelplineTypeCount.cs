namespace AKA.CMS.Domain.Entities;

public sealed class HelplineTypeCount
{
    public string CallType { get; set; } = string.Empty;
    public int CallCount { get; set; }
}
