namespace AKA.CMS.Application.DTOs;

public sealed class SaveRiskAssessmentRequest
{
    public string? PresentingConcern { get; set; }
    public string? PrimaryMhIssue { get; set; }
    public string? PrimaryMhIssueOther { get; set; }
    public string? IsCrisis { get; set; }
    public string? CrisisType { get; set; }
    public string? RiskCategory { get; set; }
    public string? SuicidalIdeation { get; set; }
    public string? SelfHarmRisk { get; set; }
    public string? ViolenceRisk { get; set; }
    public string? SeverityImmediacy { get; set; }
    public string? AccessToMeans { get; set; }
    public string? SafeguardingConcerns { get; set; }
    public string? PreviousAttempts { get; set; }
    public string? CurrentSupports { get; set; }
    public string? ProtectiveFactors { get; set; }
    public string? BarriersToCare { get; set; }
    public string? SafetyPlanFilled { get; set; }
    public string? SocialDeterminantIssues { get; set; }
    public string? SocialDeterminantOther { get; set; }
    public string? SupervisorNotified { get; set; }
    public DateTime? SupervisorNotifiedAt { get; set; }
    public string? AssessorName { get; set; }
    public DateTime? AssessedAt { get; set; }
}

public sealed class RiskAssessmentDto
{
    public int AssessmentId { get; set; }
    public int CaseId { get; set; }
    public string? PresentingConcern { get; set; }
    public string? PrimaryMhIssue { get; set; }
    public string? PrimaryMhIssueOther { get; set; }
    public string? IsCrisis { get; set; }
    public string? CrisisType { get; set; }
    public string? RiskCategory { get; set; }
    public string? SuicidalIdeation { get; set; }
    public string? SelfHarmRisk { get; set; }
    public string? ViolenceRisk { get; set; }
    public string? SeverityImmediacy { get; set; }
    public string? AccessToMeans { get; set; }
    public string? SafeguardingConcerns { get; set; }
    public string? PreviousAttempts { get; set; }
    public string? CurrentSupports { get; set; }
    public string? ProtectiveFactors { get; set; }
    public string? BarriersToCare { get; set; }
    public string? SafetyPlanFilled { get; set; }
    public string? SocialDeterminantIssues { get; set; }
    public string? SocialDeterminantOther { get; set; }
    public string? SupervisorNotified { get; set; }
    public DateTime? SupervisorNotifiedAt { get; set; }
    public string? AssessorName { get; set; }
    public DateTime? AssessedAt { get; set; }
}
