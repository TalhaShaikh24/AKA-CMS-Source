using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using AKA.CMS.Domain.Entities;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class GeographyService(
    IGeographyRepository geographyRepository,
    IValidator<CreateRegionRequest> createRegionValidator,
    IValidator<UpdateRegionRequest> updateRegionValidator,
    IValidator<CreateLocalCouncilRequest> createCouncilValidator,
    IValidator<UpdateLocalCouncilRequest> updateCouncilValidator,
    IValidator<CreateVillageRequest> createVillageValidator,
    IValidator<UpdateVillageRequest> updateVillageValidator) : IGeographyService
{
    public async Task<IReadOnlyList<RegionDto>> GetRegionsAsync(bool includeInactive = false)
        => (await geographyRepository.GetRegionsAsync(includeInactive)).Select(r => r.ToDto()).ToList();

    public async Task<RegionDto> GetRegionByIdAsync(int regionId)
        => (await geographyRepository.GetRegionByIdAsync(regionId)
            ?? throw new NotFoundException($"Region {regionId} not found.")).ToDto();

    public async Task<RegionDto> CreateRegionAsync(CreateRegionRequest request, int performedBy, string ipAddress)
    {
        await createRegionValidator.ValidateAndThrowAsync(request);
        var id = await geographyRepository.CreateRegionAsync(
            new Region { RegionName = request.RegionName.Trim(), IsActive = true }, performedBy, ipAddress);
        return await GetRegionByIdAsync(id);
    }

    public async Task<RegionDto> UpdateRegionAsync(int regionId, UpdateRegionRequest request, int performedBy, string ipAddress)
    {
        await updateRegionValidator.ValidateAndThrowAsync(request);
        await geographyRepository.UpdateRegionAsync(
            new Region { RegionId = regionId, RegionName = request.RegionName.Trim(), IsActive = request.IsActive, RowVersion = request.RowVersion },
            performedBy);
        return await GetRegionByIdAsync(regionId);
    }

    public async Task<IReadOnlyList<LocalCouncilDto>> GetLocalCouncilsAsync(int? regionId = null, bool includeInactive = false)
        => (await geographyRepository.GetLocalCouncilsAsync(regionId, includeInactive)).Select(c => c.ToDto()).ToList();

    public async Task<LocalCouncilDto> GetLocalCouncilByIdAsync(int councilId)
        => (await geographyRepository.GetLocalCouncilByIdAsync(councilId)
            ?? throw new NotFoundException($"Local council {councilId} not found.")).ToDto();

    public async Task<LocalCouncilDto> CreateLocalCouncilAsync(CreateLocalCouncilRequest request, int performedBy, string ipAddress)
    {
        await createCouncilValidator.ValidateAndThrowAsync(request);
        var id = await geographyRepository.CreateLocalCouncilAsync(
            new LocalCouncil { RegionId = request.RegionId, CouncilName = request.CouncilName.Trim(), IsActive = true },
            performedBy, ipAddress);
        return await GetLocalCouncilByIdAsync(id);
    }

    public async Task<LocalCouncilDto> UpdateLocalCouncilAsync(int councilId, UpdateLocalCouncilRequest request, int performedBy, string ipAddress)
    {
        await updateCouncilValidator.ValidateAndThrowAsync(request);
        await geographyRepository.UpdateLocalCouncilAsync(
            new LocalCouncil { CouncilId = councilId, RegionId = request.RegionId, CouncilName = request.CouncilName.Trim(), IsActive = request.IsActive, RowVersion = request.RowVersion },
            performedBy);
        return await GetLocalCouncilByIdAsync(councilId);
    }

    public async Task<IReadOnlyList<VillageDto>> GetVillagesAsync(int? councilId = null, bool includeInactive = false)
        => (await geographyRepository.GetVillagesAsync(councilId, includeInactive)).Select(v => v.ToDto()).ToList();

    public async Task<VillageDto> GetVillageByIdAsync(int villageId)
        => (await geographyRepository.GetVillageByIdAsync(villageId)
            ?? throw new NotFoundException($"Village {villageId} not found.")).ToDto();

    public async Task<VillageDto> CreateVillageAsync(CreateVillageRequest request, int performedBy, string ipAddress)
    {
        await createVillageValidator.ValidateAndThrowAsync(request);
        var id = await geographyRepository.CreateVillageAsync(
            new Village { CouncilId = request.CouncilId, VillageName = request.VillageName.Trim(), IsActive = true },
            performedBy, ipAddress);
        return await GetVillageByIdAsync(id);
    }

    public async Task<VillageDto> UpdateVillageAsync(int villageId, UpdateVillageRequest request, int performedBy, string ipAddress)
    {
        await updateVillageValidator.ValidateAndThrowAsync(request);
        await geographyRepository.UpdateVillageAsync(
            new Village { VillageId = villageId, CouncilId = request.CouncilId, VillageName = request.VillageName.Trim(), IsActive = request.IsActive, RowVersion = request.RowVersion },
            performedBy);
        return await GetVillageByIdAsync(villageId);
    }
}
