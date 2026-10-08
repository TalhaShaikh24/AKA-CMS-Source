namespace AKA.CMS.Domain.Entities;

public sealed class TaskItem
{
    public int TaskId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public int CaseId { get; set; }
    public string CaseNumber { get; set; } = string.Empty;
    public string? PatientName { get; set; }
    public string TaskType { get; set; } = "General";
    public string Priority { get; set; } = "Medium";
    public DateTime DueDate { get; set; }
    public int? AssignedToRoleId { get; set; }
    public string? AssignedRoleName { get; set; }
    public int? AssignedToUserId { get; set; }
    public string? AssignedUserName { get; set; }
    public string? NotifyRecipients { get; set; }
    public string Status { get; set; } = "Pending";
    public DateTime? CompletedAt { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
