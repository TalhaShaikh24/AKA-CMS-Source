namespace AKA.CMS.Application.DTOs;

public sealed record CreateTreatmentPlanRequest(
    int CaseId,
    string PlanTrack,
    string Title,
    string? Goals,
    string? PlannedInterventions,
    DateTime StartDate,
    DateTime? PlannedEndDate);
