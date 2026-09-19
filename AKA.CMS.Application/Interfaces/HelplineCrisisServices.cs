using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

/// <summary>
/// Crisis detection engine — maps helpline indicators to crisis types
/// per Technical Proposal v1 Phase C ("Crisis Detection" trigger
/// conditions: suicidal intent, severe self-harm risk, psychosis,
/// panic attack, substance crisis).
/// </summary>
public interface ICrisisDetectionService
{
    /// <returns>(typeCodesCsv, severity, indicatorsJson) — empty CSV when no crisis detected.</returns>
    (string TypeCodesCsv, string? Severity, string IndicatorsJson) Detect(CrisisIndicatorsDto indicators);
}

public interface IHelplineService
{
    Task<LogHelplineCallResponse> LogCallAsync(
        LogHelplineCallRequest request, Func<string, bool> hasPermission,
        int performedBy, string ipAddress);
    Task<IReadOnlyList<HelplineCallDto>> GetCallsAsync(int? caseId, int top);
}

public interface ICrisisService
{
    Task<TriggerCrisisEventResponse> TriggerAsync(
        TriggerCrisisEventRequest request, Func<string, bool> hasPermission,
        int performedBy, string ipAddress);
    Task<UpdateCrisisEventStatusResponse> UpdateStatusAsync(
        int crisisEventId, UpdateCrisisEventStatusRequest request,
        Func<string, bool> hasPermission, int performedBy, string ipAddress);
    Task<IReadOnlyList<CrisisEventDto>> GetByCaseAsync(int caseId);
    Task<IReadOnlyList<CrisisTypeDto>> GetTypesAsync();
}

public interface ISafetyPlanService
{
    Task<SafetyPlanDto> CreateAsync(CreateSafetyPlanRequest request, int performedBy, string ipAddress);
    Task<IReadOnlyList<SafetyPlanDto>> GetByCaseAsync(int caseId);
}
