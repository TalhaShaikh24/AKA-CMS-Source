namespace AKA.CMS.Application.DTOs;

public sealed record CrisisTypeDto(
    string CrisisTypeCode,
    string DisplayName,
    string DefaultSeverity,
    string? Description,
    int SortOrder);

public sealed record TriggerCrisisEventRequest(
    int CaseId,
    string CrisisTypeCode,
    string Severity,
    string TriggerSource, // HELPLINE_CALL / SCREENING_SEVERE / MANUAL
    string? Notes);

public sealed record TriggerCrisisEventResponse(
    CrisisEventDto Event,
    bool CaseTransitionApplied,
    string? CaseTransitionNote);

public sealed record UpdateCrisisEventStatusRequest(
    string NewStatus, // STABILIZED / ESCALATED / CONTINUE_CARE
    byte[] RowVersion);

public sealed record UpdateCrisisEventStatusResponse(
    CrisisEventDto Event,
    bool CaseTransitionApplied,
    string? CaseTransitionNote);

public sealed record CrisisEventDto(
    int CrisisEventId,
    int CaseId,
    string CrisisTypeCode,
    string? CrisisTypeName,
    string Severity,
    string TriggerSource,
    string Status,
    string? Notes,
    int CreatedBy,
    string? CreatedByUsername,
    DateTime CreatedAt,
    DateTime? UpdatedAt,
    byte[] RowVersion);
