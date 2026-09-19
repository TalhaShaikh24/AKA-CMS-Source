using AKA.CMS.Application.DTOs;
using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IHelplineRepository
{
    Task<(int CallId, int? CrisisEventId, int? NotificationId)> LogCallAsync(
        string? callerName, string? callerPhone, int? caseId,
        string? indicatorsJson, string? crisisTypeCodes, string? crisisSeverity,
        string? callNotes, int handledBy, string ipAddress);
    Task<HelplineCall> GetByIdAsync(int callId);
    Task<IReadOnlyList<HelplineCall>> GetListAsync(int? caseId, int top);
}

public interface ICrisisRepository
{
    Task<(int EventId, int NotificationId)> TriggerAsync(
        int caseId, string crisisTypeCode, string severity, string triggerSource,
        string? notes, int performedBy, string ipAddress);
    Task<(int CaseId, byte[] CaseRowVersion)> UpdateStatusAsync(
        int crisisEventId, string newStatus, byte[] rowVersion, int performedBy, string ipAddress);
    Task<CrisisEvent> GetByIdAsync(int crisisEventId);
    Task<IReadOnlyList<CrisisEvent>> GetByCaseAsync(int caseId);
    Task<IReadOnlyList<CrisisType>> GetTypesAsync();
}

public interface ISafetyPlanRepository
{
    Task<int> CreateAsync(
        int caseId, string warningSigns, string copingStrategies,
        string? supportContactsJson, int createdBy, string ipAddress);
    Task<SafetyPlan> GetByIdAsync(int planId);
    Task<IReadOnlyList<SafetyPlan>> GetByCaseAsync(int caseId);
}
