namespace AKA.CMS.Application.DTOs;

public sealed record ActionCarePlanDto(
    int ActionCarePlanId,
    int CaseId,
    string RiskCategory,
    string Title,
    IReadOnlyList<CarePlanStepDto> Steps,
    string Status,
    int CreatedBy,
    string? CreatedByUsername,
    DateTime CreatedAt,
    byte[] RowVersion);
