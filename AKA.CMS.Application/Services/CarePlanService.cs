using System.Text.Json;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class CarePlanService(
    ICarePlanRepository carePlanRepository,
    IValidator<CreateCarePlanRequest> createValidator) : ICarePlanService
{
    public async Task<IReadOnlyList<RiskRoutingRuleDto>> GetRoutingRulesAsync()
    {
        var rules = await carePlanRepository.GetRoutingRulesAsync();
        return rules.Select(r => r.ToDto()).ToList();
    }

    public async Task<ActionCarePlanDto> CreateAsync(
        CreateCarePlanRequest request, int performedBy, string ipAddress)
    {
        await createValidator.ValidateAndThrowAsync(request);

        var stepsJson = request.Steps is null
            ? null
            : JsonSerializer.Serialize(request.Steps);

        var planId = await carePlanRepository.CreateAsync(
            request.CaseId, request.RiskCategory.ToUpperInvariant(),
            request.Title, stepsJson, performedBy, ipAddress);

        var plans = await carePlanRepository.GetByCaseAsync(request.CaseId);
        return plans.First(p => p.ActionCarePlanId == planId).ToDto();
    }

    public async Task<IReadOnlyList<ActionCarePlanDto>> GetByCaseAsync(int caseId)
    {
        var plans = await carePlanRepository.GetByCaseAsync(caseId);
        return plans.Select(p => p.ToDto()).ToList();
    }
}
