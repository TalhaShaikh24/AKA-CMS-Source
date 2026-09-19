namespace AKA.CMS.Application.DTOs;

public sealed record RiskRoutingRuleDto(
    string RiskCategory,
    string DisplayName,
    int SlaHours,
    string[] ReferralTargets,
    bool RequiresSupervisorAlert,
    IReadOnlyList<CarePlanStepDto> CarePlanSteps);
