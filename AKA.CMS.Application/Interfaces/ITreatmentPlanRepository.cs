using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface ITreatmentPlanRepository
{
    Task<int> CreateAsync(
        int caseId, string planTrack, string title, string? goals,
        string? plannedInterventions, DateTime startDate, DateTime? plannedEndDate,
        int createdBy, string ipAddress);
    Task UpdateAsync(
        int planId, string title, string? goals, string? plannedInterventions,
        DateTime? plannedEndDate, string status,
        byte[] rowVersion, int performedBy, string ipAddress);
    Task<TreatmentPlan?> GetByIdAsync(int planId);
    Task<IReadOnlyList<TreatmentPlan>> GetByCaseAsync(int caseId);
}
