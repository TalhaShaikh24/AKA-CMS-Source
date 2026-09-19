namespace AKA.CMS.Application.DTOs;

public sealed record CreateAwarenessSessionRequest(
    string Title,
    string? FacilityCode,
    DateTime SessionDate,
    int? ConductedBy,
    string? Topic,
    string? TargetGroup,
    string? Venue,
    int MaleCount,
    int FemaleCount,
    int OtherCount,
    string? Notes);
