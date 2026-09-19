namespace AKA.CMS.Domain.Entities;

public sealed class StateCaseCount
{
    public string StateCode { get; set; } = string.Empty;
    public string StateName { get; set; } = string.Empty;
    public int CaseCount { get; set; }
}
