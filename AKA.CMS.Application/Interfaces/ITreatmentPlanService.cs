using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface ITreatmentPlanService
{
    Task<TreatmentPlanDto> CreateAsync(CreateTreatmentPlanRequest request, int performedBy, string ipAddress);
    Task<TreatmentPlanDto> GetByIdAsync(int planId);
    Task<IReadOnlyList<TreatmentPlanDto>> GetByCaseAsync(int caseId);
    Task<TreatmentPlanDto> UpdateAsync(int planId, UpdateTreatmentPlanRequest request, int performedBy, string ipAddress);
}
