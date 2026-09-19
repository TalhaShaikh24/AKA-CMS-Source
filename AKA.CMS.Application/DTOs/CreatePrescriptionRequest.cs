namespace AKA.CMS.Application.DTOs;

public sealed record CreatePrescriptionRequest(
    int CaseId,
    int? PlanId,
    int MedicationId,
    int? PrescribedByUserId,
    string DoseText,
    string Frequency,
    int DurationDays,
    string? Instructions,
    string? DiagnosisText);
