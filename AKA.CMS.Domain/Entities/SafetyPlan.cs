namespace AKA.CMS.Domain.Entities;

public sealed class SafetyPlan
{
    public int SafetyPlanId { get; set; }
    public int CaseId { get; set; }
    public string WarningSigns { get; set; } = string.Empty;
    public string CopingStrategies { get; set; } = string.Empty;
    public string? SupportContactsJson { get; set; }
    public int CreatedBy { get; set; }
    public string? CreatedByUsername { get; set; }
    public DateTime CreatedAt { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
