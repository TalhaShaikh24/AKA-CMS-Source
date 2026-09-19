using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IMedicationRepository
{
    Task<IReadOnlyList<Medication>> GetDictionaryAsync();
    Task<(int PrescriptionId, string RxNumber)> CreatePrescriptionAsync(
        int caseId, int? planId, int medicationId, int? prescribedByUserId,
        string doseText, string frequency, int durationDays,
        string? instructions, string? diagnosisText,
        int createdBy, string ipAddress);
    Task CancelPrescriptionAsync(
        int prescriptionId, byte[] rowVersion, int performedBy, string ipAddress);
    Task<IReadOnlyList<MedicationPrescription>> GetPrescriptionsByCaseAsync(int caseId);
    Task<int> DispenseAsync(
        int prescriptionId, DateTime dispensedDate, decimal quantity,
        int? dispensedByUserId, string? adherenceNotes,
        int createdBy, string ipAddress);
}
