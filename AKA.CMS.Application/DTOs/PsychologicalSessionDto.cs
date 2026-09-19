namespace AKA.CMS.Application.DTOs;

public sealed record PsychologicalSessionDto(
    int SessionId,
    int PlanId,
    int CaseId,
    int? TherapistUserId,
    DateTime SessionDate,
    string ModalityCode,
    string? ModalityName,
    int? DurationMinutes,
    string? SessionNotes,
    string? OutcomeNotes,
    DateTime? NextSessionDate,
    byte[] RowVersion,
    DateTime CreatedAt);
