namespace AKA.CMS.Application.DTOs;

public sealed record RouteCaseRequest(
    int CaseId,
    string? RiskCategory);
