namespace AKA.CMS.Application.DTOs;

public sealed record CreateCarePlanRequest(
    int CaseId,
    string RiskCategory,
    string? Title,
    IReadOnlyList<CarePlanStepDto>? Steps);
