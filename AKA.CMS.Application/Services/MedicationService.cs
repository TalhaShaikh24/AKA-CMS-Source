using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class MedicationService(
    IMedicationRepository medicationRepository,
    IValidator<CreatePrescriptionRequest> createValidator,
    IValidator<CancelPrescriptionRequest> cancelValidator,
    IValidator<DispenseMedicationRequest> dispenseValidator) : IMedicationService
{
    public async Task<IReadOnlyList<MedicationDto>> GetDictionaryAsync()
    {
        var entries = await medicationRepository.GetDictionaryAsync();
        return entries.Select(m => m.ToDto()).ToList();
    }

    public async Task<MedicationPrescriptionDto> CreatePrescriptionAsync(
        CreatePrescriptionRequest request, int performedBy, string ipAddress)
    {
        await createValidator.ValidateAndThrowAsync(request);

        var (prescriptionId, _) = await medicationRepository.CreatePrescriptionAsync(
            request.CaseId, request.PlanId, request.MedicationId, request.PrescribedByUserId,
            request.DoseText, request.Frequency, request.DurationDays,
            request.Instructions, request.DiagnosisText,
            performedBy, ipAddress);

        var prescriptions = await medicationRepository.GetPrescriptionsByCaseAsync(request.CaseId);
        return prescriptions.First(p => p.PrescriptionId == prescriptionId).ToDto();
    }

    public async Task CancelPrescriptionAsync(
        int prescriptionId, byte[] rowVersion, int performedBy, string ipAddress)
    {
        await cancelValidator.ValidateAndThrowAsync(new CancelPrescriptionRequest(rowVersion));

        await medicationRepository.CancelPrescriptionAsync(
            prescriptionId, rowVersion, performedBy, ipAddress);
    }

    public async Task<IReadOnlyList<MedicationPrescriptionDto>> GetPrescriptionsByCaseAsync(int caseId)
    {
        var prescriptions = await medicationRepository.GetPrescriptionsByCaseAsync(caseId);
        return prescriptions.Select(p => p.ToDto()).ToList();
    }

    public async Task<int> DispenseAsync(
        int prescriptionId, DispenseMedicationRequest request, int performedBy, string ipAddress)
    {
        await dispenseValidator.ValidateAndThrowAsync(request);

        return await medicationRepository.DispenseAsync(
            prescriptionId, request.DispensedDate, request.Quantity,
            request.DispensedByUserId, request.AdherenceNotes,
            performedBy, ipAddress);
    }
}
