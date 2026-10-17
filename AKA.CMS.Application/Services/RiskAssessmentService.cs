using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Services;

public sealed class RiskAssessmentService(IRiskAssessmentRepository repository) : IRiskAssessmentService
{
    public async Task<RiskAssessmentDto> SaveAsync(int caseId, SaveRiskAssessmentRequest request, int performedBy)
    {
        var assessment = new CaseRiskAssessment
        {
            CaseId = caseId,
            PresentingConcern = request.PresentingConcern,
            PrimaryMhIssue = request.PrimaryMhIssue,
            PrimaryMhIssueOther = request.PrimaryMhIssueOther,
            IsCrisis = request.IsCrisis,
            CrisisType = request.CrisisType,
            RiskCategory = request.RiskCategory,
            SuicidalIdeation = request.SuicidalIdeation,
            SelfHarmRisk = request.SelfHarmRisk,
            ViolenceRisk = request.ViolenceRisk,
            SeverityImmediacy = request.SeverityImmediacy,
            AccessToMeans = request.AccessToMeans,
            SafeguardingConcerns = request.SafeguardingConcerns,
            PreviousAttempts = request.PreviousAttempts,
            CurrentSupports = request.CurrentSupports,
            ProtectiveFactors = request.ProtectiveFactors,
            BarriersToCare = request.BarriersToCare,
            SafetyPlanFilled = request.SafetyPlanFilled,
            SocialDeterminantIssues = request.SocialDeterminantIssues,
            SocialDeterminantOther = request.SocialDeterminantOther,
            SupervisorNotified = request.SupervisorNotified,
            SupervisorNotifiedAt = request.SupervisorNotifiedAt,
            AssessorName = request.AssessorName,
            AssessedAt = request.AssessedAt
        };

        await repository.SaveAsync(assessment, performedBy);
        var saved = await repository.GetByCaseAsync(caseId)
            ?? throw new NotFoundException($"Risk assessment for case {caseId} not found.");
        return ToDto(saved);
    }

    public async Task<RiskAssessmentDto?> GetByCaseAsync(int caseId)
    {
        var assessment = await repository.GetByCaseAsync(caseId);
        return assessment is null ? null : ToDto(assessment);
    }

    private static RiskAssessmentDto ToDto(CaseRiskAssessment a) => new()
    {
        AssessmentId = a.AssessmentId,
        CaseId = a.CaseId,
        PresentingConcern = a.PresentingConcern,
        PrimaryMhIssue = a.PrimaryMhIssue,
        PrimaryMhIssueOther = a.PrimaryMhIssueOther,
        IsCrisis = a.IsCrisis,
        CrisisType = a.CrisisType,
        RiskCategory = a.RiskCategory,
        SuicidalIdeation = a.SuicidalIdeation,
        SelfHarmRisk = a.SelfHarmRisk,
        ViolenceRisk = a.ViolenceRisk,
        SeverityImmediacy = a.SeverityImmediacy,
        AccessToMeans = a.AccessToMeans,
        SafeguardingConcerns = a.SafeguardingConcerns,
        PreviousAttempts = a.PreviousAttempts,
        CurrentSupports = a.CurrentSupports,
        ProtectiveFactors = a.ProtectiveFactors,
        BarriersToCare = a.BarriersToCare,
        SafetyPlanFilled = a.SafetyPlanFilled,
        SocialDeterminantIssues = a.SocialDeterminantIssues,
        SocialDeterminantOther = a.SocialDeterminantOther,
        SupervisorNotified = a.SupervisorNotified,
        SupervisorNotifiedAt = a.SupervisorNotifiedAt,
        AssessorName = a.AssessorName,
        AssessedAt = a.AssessedAt
    };
}
