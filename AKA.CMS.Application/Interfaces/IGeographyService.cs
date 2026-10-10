using AKA.CMS.Application.DTOs;
using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IGeographyService
{
    Task<IReadOnlyList<RegionDto>> GetRegionsAsync(bool includeInactive = false);
    Task<RegionDto> GetRegionByIdAsync(int regionId);
    Task<RegionDto> CreateRegionAsync(CreateRegionRequest request, int performedBy, string ipAddress);
    Task<RegionDto> UpdateRegionAsync(int regionId, UpdateRegionRequest request, int performedBy, string ipAddress);

    Task<IReadOnlyList<LocalCouncilDto>> GetLocalCouncilsAsync(int? regionId = null, bool includeInactive = false);
    Task<LocalCouncilDto> GetLocalCouncilByIdAsync(int councilId);
    Task<LocalCouncilDto> CreateLocalCouncilAsync(CreateLocalCouncilRequest request, int performedBy, string ipAddress);
    Task<LocalCouncilDto> UpdateLocalCouncilAsync(int councilId, UpdateLocalCouncilRequest request, int performedBy, string ipAddress);

    Task<IReadOnlyList<VillageDto>> GetVillagesAsync(int? councilId = null, bool includeInactive = false);
    Task<VillageDto> GetVillageByIdAsync(int villageId);
    Task<VillageDto> CreateVillageAsync(CreateVillageRequest request, int performedBy, string ipAddress);
    Task<VillageDto> UpdateVillageAsync(int villageId, UpdateVillageRequest request, int performedBy, string ipAddress);
}

public interface IGeographyRepository
{
    Task<IReadOnlyList<Region>> GetRegionsAsync(bool includeInactive);
    Task<Region?> GetRegionByIdAsync(int regionId);
    Task<int> CreateRegionAsync(Region region, int performedBy, string ipAddress);
    Task UpdateRegionAsync(Region region, int performedBy);

    Task<IReadOnlyList<LocalCouncil>> GetLocalCouncilsAsync(int? regionId, bool includeInactive);
    Task<LocalCouncil?> GetLocalCouncilByIdAsync(int councilId);
    Task<int> CreateLocalCouncilAsync(LocalCouncil council, int performedBy, string ipAddress);
    Task UpdateLocalCouncilAsync(LocalCouncil council, int performedBy);

    Task<IReadOnlyList<Village>> GetVillagesAsync(int? councilId, bool includeInactive);
    Task<Village?> GetVillageByIdAsync(int villageId);
    Task<int> CreateVillageAsync(Village village, int performedBy, string ipAddress);
    Task UpdateVillageAsync(Village village, int performedBy);
}
