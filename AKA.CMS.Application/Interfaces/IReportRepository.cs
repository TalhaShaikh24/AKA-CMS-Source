using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IReportRepository
{
    Task<(IReadOnlyList<StateCaseCount> ByState, IReadOnlyList<RiskBandCaseCount> ByRiskBand)>
        GetCaseSummaryAsync(DateTime? fromDate, DateTime? toDate, int? unitCode);

    Task<(IReadOnlyList<ScreeningToolSummary> Tools, IReadOnlyList<ToolRiskDistribution> RiskDistribution)>
        GetScreeningSummaryAsync(string? toolCode, DateTime? fromDate, DateTime? toDate);

    Task<(IReadOnlyList<HelplineTypeCount> ByType, IReadOnlyList<HelplineSeverityCount> BySeverity)>
        GetHelplineSummaryAsync(DateTime? fromDate, DateTime? toDate);

    Task<IReadOnlyList<FollowUpStatusCount>> GetFollowUpComplianceAsync(
        DateTime? fromDate, DateTime? toDate, int? unitCode);

    Task<IReadOnlyList<WorkloadEntry>> GetWorkloadAsync(int? unitCode);
}
