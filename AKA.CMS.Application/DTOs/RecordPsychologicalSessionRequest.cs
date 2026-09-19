namespace AKA.CMS.Application.DTOs;

public sealed record RecordPsychologicalSessionRequest(
    int PlanId,
    int CaseId,
    int? TherapistUserId,
    DateTime SessionDate,
    string ModalityCode,
    int? DurationMinutes,
    string? SessionNotes,
    string? OutcomeNotes,
    DateTime? NextSessionDate);
