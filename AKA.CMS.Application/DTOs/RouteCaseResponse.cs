namespace AKA.CMS.Application.DTOs;

public sealed record RouteCaseResponse(
    string RiskCategory,
    DateTime SlaDueAt,
    int CarePlanId,
    int QueueId,
    IReadOnlyList<int> ReferralIds,
    bool TransitionApplied,
    string? TransitionNote);
