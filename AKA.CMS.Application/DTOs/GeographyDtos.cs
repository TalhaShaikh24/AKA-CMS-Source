namespace AKA.CMS.Application.DTOs;

public sealed record RegionDto(
    int RegionId,
    string RegionName,
    bool IsActive,
    byte[] RowVersion);

public sealed record CreateRegionRequest(string RegionName);

public sealed record UpdateRegionRequest(
    string RegionName,
    bool IsActive,
    byte[] RowVersion);

public sealed record LocalCouncilDto(
    int CouncilId,
    int? RegionId,
    string? RegionName,
    string CouncilName,
    bool IsActive,
    byte[] RowVersion);

public sealed record CreateLocalCouncilRequest(
    int? RegionId,
    string CouncilName);

public sealed record UpdateLocalCouncilRequest(
    int? RegionId,
    string CouncilName,
    bool IsActive,
    byte[] RowVersion);

public sealed record VillageDto(
    int VillageId,
    int? CouncilId,
    string? CouncilName,
    string VillageName,
    bool IsActive,
    byte[] RowVersion);

public sealed record CreateVillageRequest(
    int? CouncilId,
    string VillageName);

public sealed record UpdateVillageRequest(
    int? CouncilId,
    string VillageName,
    bool IsActive,
    byte[] RowVersion);
