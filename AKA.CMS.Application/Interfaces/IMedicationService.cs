using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IMedicationService
{
    Task<IReadOnlyList<MedicationDto>> GetDictionaryAsync();
    Task<MedicationPrescriptionDto> CreatePrescriptionAsync(
        CreatePrescriptionRequest request, int performedBy, string ipAddress);
    Task CancelPrescriptionAsync(
        int prescriptionId, byte[] rowVersion, int performedBy, string ipAddress);
    Task<IReadOnlyList<MedicationPrescriptionDto>> GetPrescriptionsByCaseAsync(int caseId);
    Task<int> DispenseAsync(
        int prescriptionId, DispenseMedicationRequest request, int performedBy, string ipAddress);
}
