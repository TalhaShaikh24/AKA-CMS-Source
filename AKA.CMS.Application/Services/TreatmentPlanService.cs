using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class TreatmentPlanService(
    ITreatmentPlanRepository planRepository,
    IValidator<CreateTreatmentPlanRequest> createValidator,
    IValidator<UpdateTreatmentPlanRequest> updateValidator) : ITreatmentPlanService
{
    public async Task<TreatmentPlanDto> CreateAsync(
        CreateTreatmentPlanRequest request, int performedBy, string ipAddress)
    {
        await createValidator.ValidateAndThrowAsync(request);

        var planId = await planRepository.CreateAsync(
            request.CaseId, request.PlanTrack, request.Title, request.Goals,
            request.PlannedInterventions, request.StartDate, request.PlannedEndDate,
            performedBy, ipAddress);

        return await GetByIdAsync(planId);
    }

    public async Task<TreatmentPlanDto> GetByIdAsync(int planId)
    {
        var plan = await planRepository.GetByIdAsync(planId)
            ?? throw new NotFoundException($"Treatment plan {planId} not found.");
        return plan.ToDto();
    }

    public async Task<IReadOnlyList<TreatmentPlanDto>> GetByCaseAsync(int caseId)
    {
        var plans = await planRepository.GetByCaseAsync(caseId);
        return plans.Select(p => p.ToDto()).ToList();
    }

    public async Task<TreatmentPlanDto> UpdateAsync(
        int planId, UpdateTreatmentPlanRequest request, int performedBy, string ipAddress)
    {
        await updateValidator.ValidateAndThrowAsync(request);

        await planRepository.UpdateAsync(
            planId, request.Title, request.Goals, request.PlannedInterventions,
            request.PlannedEndDate, request.Status,
            request.RowVersion, performedBy, ipAddress);

        return await GetByIdAsync(planId);
    }
}
