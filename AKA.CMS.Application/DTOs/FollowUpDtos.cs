namespace AKA.CMS.Application.DTOs;

public sealed record FollowUpDto(
    int FollowUpId,
    int CaseId,
    DateTime ScheduledDate,
    DateTime? ActualDate,
    string FollowUpType,
    int? AssignedToUserId,
    string? Notes,
    string Status,
    string? OutcomeNotes,
    byte[] RowVersion,
    DateTime CreatedAt);

public sealed record DueFollowUpDto(
    int CaseId,
    string CaseNumber,
    string? PriorityLevel,
    string CaseStatus,
    DateTime LastContactDate,
    int DaysSinceContact,
    int FrequencyDays);

public sealed record ScheduleFollowUpRequest(
    int CaseId,
    DateTime ScheduledDate,
    string FollowUpType,
    int? AssignedToUserId,
    string? Notes);

public sealed record ScheduleFollowUpResponse(
    FollowUpDto FollowUp,
    bool CaseTransitionApplied,
    string? CaseTransitionNote);

public sealed record RecordFollowUpOutcomeRequest(
    string Outcome,
    string? OutcomeNotes,
    DateTime? ActualDate,
    byte[] RowVersion);

public sealed record RecordFollowUpOutcomeResponse(
    FollowUpDto FollowUp,
    bool LtfuDeclared,
    bool CaseTransitionApplied,
    string? CaseTransitionNote);
