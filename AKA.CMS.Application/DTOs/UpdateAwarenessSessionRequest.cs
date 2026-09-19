namespace AKA.CMS.Application.DTOs;

public sealed record UpdateAwarenessSessionRequest(
    string Title,
    string? FacilityCode,
    DateTime SessionDate,
    string? Topic,
    string? TargetGroup,
    string? Venue,
    int MaleCount,
    int FemaleCount,
    int OtherCount,
    string? Notes,
    byte[] RowVersion);
