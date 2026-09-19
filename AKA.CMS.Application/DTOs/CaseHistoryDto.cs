namespace AKA.CMS.Application.DTOs;

public sealed record CaseHistoryDto(
    int HistoryId,
    int CaseId,
    string FromState,
    string ToState,
    string ActionCode,
    string? Comment,
    int PerformedBy,
    string? PerformedByUsername,
    DateTime PerformedAt);
