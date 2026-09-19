using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;

namespace AKA.CMS.Application.Services;

public sealed class ReportService(IReportRepository reportRepository) : IReportService
{
    public async Task<CaseSummaryDto> GetCaseSummaryAsync(
        DateTime? fromDate, DateTime? toDate, int? unitCode)
    {
        var (byState, byRiskBand) = await reportRepository.GetCaseSummaryAsync(fromDate, toDate, unitCode);
        return new CaseSummaryDto(
            byState.Select(s => new StateCaseCountDto(s.StateCode, s.StateName, s.CaseCount)).ToList(),
            byRiskBand.Select(b => new RiskBandCaseCountDto(b.RiskBand, b.CaseCount)).ToList());
    }

    public async Task<ScreeningSummaryDto> GetScreeningSummaryAsync(
        string? toolCode, DateTime? fromDate, DateTime? toDate)
    {
        var (tools, distribution) = await reportRepository.GetScreeningSummaryAsync(toolCode, fromDate, toDate);
        return new ScreeningSummaryDto(
            tools.Select(t => new ScreeningToolSummaryDto(
                t.ToolCode, t.ToolName, t.ScreeningCount, t.AvgScore, t.MinScore, t.MaxScore)).ToList(),
            distribution.Select(d => new ToolRiskDistributionDto(
                d.ToolCode, d.RiskLevel, d.ScreeningCount)).ToList());
    }

    public async Task<HelplineSummaryDto> GetHelplineSummaryAsync(
        DateTime? fromDate, DateTime? toDate)
    {
        var (byType, bySeverity) = await reportRepository.GetHelplineSummaryAsync(fromDate, toDate);
        return new HelplineSummaryDto(
            byType.Select(t => new LabelCountDto(t.CallType, t.CallCount)).ToList(),
            bySeverity.Select(s => new LabelCountDto(s.Severity, s.CallCount)).ToList());
    }

    public async Task<FollowUpComplianceDto> GetFollowUpComplianceAsync(
        DateTime? fromDate, DateTime? toDate, int? unitCode)
    {
        var statuses = await reportRepository.GetFollowUpComplianceAsync(fromDate, toDate, unitCode);
        return new FollowUpComplianceDto(
            statuses.Select(s => new LabelCountDto(s.Status, s.FollowUpCount)).ToList());
    }

    public async Task<WorkloadDto> GetWorkloadAsync(int? unitCode)
    {
        var entries = await reportRepository.GetWorkloadAsync(unitCode);
        return new WorkloadDto(
            entries.Select(e => new WorkloadEntryDto(
                e.AssignedToUserId, e.Username, e.OpenCaseCount)).ToList());
    }
}
