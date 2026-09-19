namespace AKA.CMS.Domain.Entities;

public sealed class RiskRoutingRule
{
    public string RiskCategory { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public int SlaHours { get; set; }
    public string ReferralTargets { get; set; } = string.Empty;
    public bool RequiresSupervisorAlert { get; set; }
    public string CarePlanStepsJson { get; set; } = "[]";
}
