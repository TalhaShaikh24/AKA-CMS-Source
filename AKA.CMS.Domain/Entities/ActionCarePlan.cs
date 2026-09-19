namespace AKA.CMS.Domain.Entities;

public sealed class ActionCarePlan
{
    public int ActionCarePlanId { get; set; }
    public int CaseId { get; set; }
    public string RiskCategory { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string StepsJson { get; set; } = "[]";
    public string Status { get; set; } = string.Empty;
    public int CreatedBy { get; set; }
    public string? CreatedByUsername { get; set; }
    public DateTime CreatedAt { get; set; }
    public byte[] RowVersion { get; set; } = [];
}
