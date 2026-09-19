namespace AKA.CMS.Application.DTOs;

public sealed record MedicationDto(
    int MedicationId,
    string MedicationCode,
    string GenericName,
    string? Strength,
    string? DosageForm,
    bool ClinicalConfirmationPending,
    int SortOrder);
