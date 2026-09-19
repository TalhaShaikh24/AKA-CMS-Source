namespace AKA.CMS.Domain.Entities;

public sealed class SupervisionLog
{
    public int SupervisionLogId { get; set; }
    public int CaseId { get; set; }
    public int SupervisorUserId { get; set; }
    public DateTime ReviewDate { get; set; }
    public string Findings { get; set; } = string.Empty;
    public string? ActionItems { get; set; }
    public string? Rating { get; set; }
    public byte[] RowVersion { get; set; } = [];
    public bool IsActive { get; set; }
    public int CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}
