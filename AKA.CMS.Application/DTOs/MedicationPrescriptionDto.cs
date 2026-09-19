namespace AKA.CMS.Application.DTOs;

public sealed record MedicationPrescriptionDto(
    int PrescriptionId,
    string RxNumber,
    int CaseId,
    int? PlanId,
    int MedicationId,
    string MedicationCode,
    string GenericName,
    string? Strength,
    string? DosageForm,
    int? PrescribedByUserId,
    string DoseText,
    string Frequency,
    int DurationDays,
    string? Instructions,
    string? DiagnosisText,
    string Status,
    byte[] RowVersion,
    DateTime CreatedAt,
    int DispenseCount);
