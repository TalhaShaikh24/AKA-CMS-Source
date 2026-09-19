namespace AKA.CMS.Domain.Entities;

public sealed class WorkflowTransition
{
    public int TransitionId { get; set; }
    public string ActionCode { get; set; } = string.Empty;
    public string ActionName { get; set; } = string.Empty;
    public string FromState { get; set; } = string.Empty;
    public string ToState { get; set; } = string.Empty;
    public string? ToStateName { get; set; }
    public string RequiredPermissionName { get; set; } = string.Empty;
    public int SortOrder { get; set; }
    public bool IsActive { get; set; }
    public byte[] RowVersion { get; set; } = Array.Empty<byte>();
}
