using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class SafetyPlanService(
    ISafetyPlanRepository safetyPlanRepository,
    IValidator<CreateSafetyPlanRequest> createValidator) : ISafetyPlanService
{
    public async Task<SafetyPlanDto> CreateAsync(
        CreateSafetyPlanRequest request, int performedBy, string ipAddress)
    {
        await createValidator.ValidateAndThrowAsync(request);

        var planId = await safetyPlanRepository.CreateAsync(
            request.CaseId, request.WarningSigns, request.CopingStrategies,
            request.SupportContactsJson, performedBy, ipAddress);

        var plan = await safetyPlanRepository.GetByIdAsync(planId);
        return plan.ToDto();
    }

    public async Task<IReadOnlyList<SafetyPlanDto>> GetByCaseAsync(int caseId)
    {
        var plans = await safetyPlanRepository.GetByCaseAsync(caseId);
        return plans.Select(p => p.ToDto()).ToList();
    }
}
