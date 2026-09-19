namespace AKA.CMS.Application.DTOs;

public sealed record SupervisionLogDto(
    int SupervisionLogId,
    int CaseId,
    int SupervisorUserId,
    DateTime ReviewDate,
    string Findings,
    string? ActionItems,
    string? Rating,
    byte[] RowVersion,
    DateTime CreatedAt);

public sealed record LogSupervisionRequest(
    int CaseId,
    int SupervisorUserId,
    DateTime ReviewDate,
    string Findings,
    string? ActionItems,
    string? Rating);
