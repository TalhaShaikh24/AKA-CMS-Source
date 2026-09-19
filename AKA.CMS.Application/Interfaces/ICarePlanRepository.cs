using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface ICarePlanRepository
{
    Task<IReadOnlyList<RiskRoutingRule>> GetRoutingRulesAsync();
    Task<int> CreateAsync(int caseId, string riskCategory, string? title, string? stepsJson, int createdBy, string ipAddress);
    Task<IReadOnlyList<ActionCarePlan>> GetByCaseAsync(int caseId);
}
