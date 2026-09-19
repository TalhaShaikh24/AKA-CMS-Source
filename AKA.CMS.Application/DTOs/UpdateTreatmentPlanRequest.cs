namespace AKA.CMS.Application.DTOs;

public sealed record UpdateTreatmentPlanRequest(
    string Title,
    string? Goals,
    string? PlannedInterventions,
    DateTime? PlannedEndDate,
    string Status,
    byte[] RowVersion);
