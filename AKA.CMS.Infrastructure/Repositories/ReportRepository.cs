using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class ReportRepository(DapperContext context) : IReportRepository
{
    public async Task<(IReadOnlyList<StateCaseCount> ByState, IReadOnlyList<RiskBandCaseCount> ByRiskBand)>
        GetCaseSummaryAsync(DateTime? fromDate, DateTime? toDate, int? unitCode)
    {
        using var connection = context.CreateConnection();
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.ReportCaseSummary,
            new { FromDate = fromDate, ToDate = toDate, UnitCode = unitCode },
            commandType: CommandType.StoredProcedure);
        var byState = (await multi.ReadAsync<StateCaseCount>()).ToList();
        var byRiskBand = (await multi.ReadAsync<RiskBandCaseCount>()).ToList();
        return (byState, byRiskBand);
    }

    public async Task<(IReadOnlyList<ScreeningToolSummary> Tools, IReadOnlyList<ToolRiskDistribution> RiskDistribution)>
        GetScreeningSummaryAsync(string? toolCode, DateTime? fromDate, DateTime? toDate)
    {
        using var connection = context.CreateConnection();
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.ReportScreeningSummary,
            new { ToolCode = toolCode, FromDate = fromDate, ToDate = toDate },
            commandType: CommandType.StoredProcedure);
        var tools = (await multi.ReadAsync<ScreeningToolSummary>()).ToList();
        var distribution = (await multi.ReadAsync<ToolRiskDistribution>()).ToList();
        return (tools, distribution);
    }

    public async Task<(IReadOnlyList<HelplineTypeCount> ByType, IReadOnlyList<HelplineSeverityCount> BySeverity)>
        GetHelplineSummaryAsync(DateTime? fromDate, DateTime? toDate)
    {
        using var connection = context.CreateConnection();
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.ReportHelplineSummary,
            new { FromDate = fromDate, ToDate = toDate },
            commandType: CommandType.StoredProcedure);
        var byType = (await multi.ReadAsync<HelplineTypeCount>()).ToList();
        var bySeverity = (await multi.ReadAsync<HelplineSeverityCount>()).ToList();
        return (byType, bySeverity);
    }

    public async Task<IReadOnlyList<FollowUpStatusCount>> GetFollowUpComplianceAsync(
        DateTime? fromDate, DateTime? toDate, int? unitCode)
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<FollowUpStatusCount>(
            StoredProcedures.ReportFollowUpCompliance,
            new { FromDate = fromDate, ToDate = toDate, UnitCode = unitCode },
            commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    public async Task<IReadOnlyList<WorkloadEntry>> GetWorkloadAsync(int? unitCode)
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<WorkloadEntry>(
            StoredProcedures.ReportWorkload,
            new { UnitCode = unitCode },
            commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }
}
