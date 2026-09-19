namespace AKA.CMS.Application.DTOs;

public sealed record CreateSafetyPlanRequest(
    int CaseId,
    string WarningSigns,
    string CopingStrategies,
    string? SupportContactsJson);

public sealed record SafetyPlanDto(
    int SafetyPlanId,
    int CaseId,
    string WarningSigns,
    string CopingStrategies,
    string? SupportContactsJson,
    int CreatedBy,
    string? CreatedByUsername,
    DateTime CreatedAt,
    byte[] RowVersion);
