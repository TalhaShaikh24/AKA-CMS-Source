using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class RiskAssessmentRepository(DapperContext context) : IRiskAssessmentRepository
{
    public async Task<int> SaveAsync(CaseRiskAssessment a, int performedBy)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@CaseId", a.CaseId);
        p.Add("@PresentingConcern", a.PresentingConcern);
        p.Add("@PrimaryMhIssue", a.PrimaryMhIssue);
        p.Add("@PrimaryMhIssueOther", a.PrimaryMhIssueOther);
        p.Add("@IsCrisis", a.IsCrisis);
        p.Add("@CrisisType", a.CrisisType);
        p.Add("@RiskCategory", a.RiskCategory);
        p.Add("@SuicidalIdeation", a.SuicidalIdeation);
        p.Add("@SelfHarmRisk", a.SelfHarmRisk);
        p.Add("@ViolenceRisk", a.ViolenceRisk);
        p.Add("@SeverityImmediacy", a.SeverityImmediacy);
        p.Add("@AccessToMeans", a.AccessToMeans);
        p.Add("@SafeguardingConcerns", a.SafeguardingConcerns);
        p.Add("@PreviousAttempts", a.PreviousAttempts);
        p.Add("@CurrentSupports", a.CurrentSupports);
        p.Add("@ProtectiveFactors", a.ProtectiveFactors);
        p.Add("@BarriersToCare", a.BarriersToCare);
        p.Add("@SafetyPlanFilled", a.SafetyPlanFilled);
        p.Add("@SocialDeterminantIssues", a.SocialDeterminantIssues);
        p.Add("@SocialDeterminantOther", a.SocialDeterminantOther);
        p.Add("@SupervisorNotified", a.SupervisorNotified);
        p.Add("@SupervisorNotifiedAt", a.SupervisorNotifiedAt);
        p.Add("@AssessorName", a.AssessorName);
        p.Add("@AssessedAt", a.AssessedAt);
        p.Add("@PerformedBy", performedBy);
        p.Add("@AssessmentId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await connection.ExecuteAsync(
            StoredProcedures.RiskAssessmentSave, p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("@AssessmentId");
    }

    public async Task<CaseRiskAssessment?> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@CaseId", caseId);
        return await connection.QuerySingleOrDefaultAsync<CaseRiskAssessment>(
            StoredProcedures.RiskAssessmentGetByCase, p, commandType: CommandType.StoredProcedure);
    }
}
