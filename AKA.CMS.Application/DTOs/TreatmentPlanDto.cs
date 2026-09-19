namespace AKA.CMS.Application.DTOs;

public sealed record TreatmentPlanDto(
    int PlanId,
    int CaseId,
    string PlanTrack,
    string Title,
    string? Goals,
    string? PlannedInterventions,
    DateTime StartDate,
    DateTime? PlannedEndDate,
    string Status,
    byte[] RowVersion,
    int PsychSessionCount,
    int PrescriptionCount,
    DateTime CreatedAt);
