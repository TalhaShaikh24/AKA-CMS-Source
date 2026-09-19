namespace AKA.CMS.Application.DTOs;

/// <summary>
/// Structured crisis-indicator flags for a helpline call.
/// Maps to the Technical Proposal v1, Phase C trigger conditions.
/// </summary>
public sealed record CrisisIndicatorsDto(
    bool SuicidalIntent,
    bool SelfHarmRisk,
    bool Psychosis,
    bool PanicAttack,
    bool SubstanceCrisis,
    bool OtherAcute);

public sealed record LogHelplineCallRequest(
    string? CallerName,
    string? CallerPhone,
    int? CaseId,
    CrisisIndicatorsDto Indicators,
    string? CallNotes);

public sealed record LogHelplineCallResponse(
    HelplineCallDto Call,
    bool CrisisEventCreated,
    int? CrisisEventId,
    bool CaseTransitionApplied,
    string? CaseTransitionNote);

public sealed record HelplineCallDto(
    int HelplineCallId,
    string? CallerName,
    string? CallerPhone,
    int? CaseId,
    string? CrisisTypeCodes,
    string? CrisisSeverity,
    string? CallNotes,
    int HandledBy,
    string? HandledByUsername,
    DateTime CallStartedAt,
    DateTime CreatedAt,
    byte[] RowVersion);
