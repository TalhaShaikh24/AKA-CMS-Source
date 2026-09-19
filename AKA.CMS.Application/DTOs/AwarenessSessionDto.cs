namespace AKA.CMS.Application.DTOs;

public sealed record AwarenessSessionDto(
    int SessionId,
    string SessionCode,
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
    string? Notes,
    byte[] RowVersion,
    int ParticipantCount,
    DateTime CreatedAt);
