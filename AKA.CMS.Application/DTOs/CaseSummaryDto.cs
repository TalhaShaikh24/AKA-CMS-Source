namespace AKA.CMS.Application.DTOs;

public sealed record StateCaseCountDto(string StateCode, string StateName, int CaseCount);

public sealed record RiskBandCaseCountDto(string RiskBand, int CaseCount);

public sealed record CaseSummaryDto(
    IReadOnlyList<StateCaseCountDto> ByState,
    IReadOnlyList<RiskBandCaseCountDto> ByRiskBand);
