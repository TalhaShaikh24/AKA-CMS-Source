using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using AKA.CMS.Domain.Entities;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class FacilityService(
    IFacilityRepository facilityRepository,
    IValidator<CreateFacilityRequest> createValidator,
    IValidator<UpdateFacilityRequest> updateValidator) : IFacilityService
{
    public async Task<IReadOnlyList<FacilityDto>> GetAllAsync(bool includeInactive = false)
    {
        var facilities = await facilityRepository.GetAllAsync(includeInactive);
        return facilities.Select(f => f.ToDto()).ToList();
    }

    public async Task<FacilityDto> GetByIdAsync(int facilityId)
    {
        var facility = await facilityRepository.GetByIdAsync(facilityId)
            ?? throw new NotFoundException($"Facility {facilityId} not found.");
        return facility.ToDto();
    }

    public async Task<FacilityDto> CreateAsync(
        CreateFacilityRequest request, int performedBy, string ipAddress)
    {
        await createValidator.ValidateAndThrowAsync(request);

        var facilityId = await facilityRepository.CreateAsync(
            new Facility
            {
                FacilityCode = request.FacilityCode,
                FacilityName = request.FacilityName,
                FacilityType = request.FacilityType,
                Region = request.Region,
                Address = request.Address,
                Phone = request.Phone,
                IsActive = true
            },
            performedBy,
            ipAddress);

        return await GetByIdAsync(facilityId);
    }

    public async Task<FacilityDto> UpdateAsync(
        int facilityId, UpdateFacilityRequest request, int performedBy, string ipAddress)
    {
        await updateValidator.ValidateAndThrowAsync(request);

        await facilityRepository.UpdateAsync(
            new Facility
            {
                FacilityId = facilityId,
                FacilityName = request.FacilityName,
                FacilityType = request.FacilityType,
                Region = request.Region,
                Address = request.Address,
                Phone = request.Phone,
                IsActive = request.IsActive,
                RowVersion = request.RowVersion
            },
            performedBy,
            ipAddress);

        return await GetByIdAsync(facilityId);
    }
}
