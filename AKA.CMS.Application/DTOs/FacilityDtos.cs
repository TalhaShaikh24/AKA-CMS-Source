namespace AKA.CMS.Application.DTOs;

public sealed record FacilityDto(
    int FacilityId,
    string FacilityCode,
    string FacilityName,
    string? FacilityType,
    string? Region,
    string? Address,
    string? Phone,
    bool IsActive,
    byte[] RowVersion);

public sealed record CreateFacilityRequest(
    string FacilityCode,
    string FacilityName,
    string? FacilityType,
    string? Region,
    string? Address,
    string? Phone);

public sealed record UpdateFacilityRequest(
    string FacilityName,
    string? FacilityType,
    string? Region,
    string? Address,
    string? Phone,
    bool IsActive,
    byte[] RowVersion);
