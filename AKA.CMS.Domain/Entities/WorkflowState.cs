namespace AKA.CMS.Domain.Entities;

public sealed class WorkflowState
{
    public string StateCode { get; set; } = string.Empty;
    public string StateName { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsInitial { get; set; }
    public bool IsTerminal { get; set; }
    public int SortOrder { get; set; }
}
