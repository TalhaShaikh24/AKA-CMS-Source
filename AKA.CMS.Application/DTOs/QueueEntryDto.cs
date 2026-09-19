namespace AKA.CMS.Application.DTOs;

public sealed record QueueEntryDto(
    int QueueId,
    int CaseId,
    string? CaseNumber,
    string RiskCategory,
    DateTime SlaDueAt,
    int? AssignedToUserId,
    string? AssignedToUsername,
    string Status,
    int EnqueuedBy,
    string? EnqueuedByUsername,
    DateTime EnqueuedAt,
    byte[] RowVersion);
