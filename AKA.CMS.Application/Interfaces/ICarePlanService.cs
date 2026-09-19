using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface ICarePlanService
{
    Task<IReadOnlyList<RiskRoutingRuleDto>> GetRoutingRulesAsync();
    Task<ActionCarePlanDto> CreateAsync(CreateCarePlanRequest request, int performedBy, string ipAddress);
    Task<IReadOnlyList<ActionCarePlanDto>> GetByCaseAsync(int caseId);
}
