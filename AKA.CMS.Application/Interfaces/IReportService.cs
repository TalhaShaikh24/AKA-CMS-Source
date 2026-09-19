using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IReportService
{
    Task<CaseSummaryDto> GetCaseSummaryAsync(
        DateTime? fromDate, DateTime? toDate, int? unitCode);
    Task<ScreeningSummaryDto> GetScreeningSummaryAsync(
        string? toolCode, DateTime? fromDate, DateTime? toDate);
    Task<HelplineSummaryDto> GetHelplineSummaryAsync(
        DateTime? fromDate, DateTime? toDate);
    Task<FollowUpComplianceDto> GetFollowUpComplianceAsync(
        DateTime? fromDate, DateTime? toDate, int? unitCode);
    Task<WorkloadDto> GetWorkloadAsync(int? unitCode);
}
