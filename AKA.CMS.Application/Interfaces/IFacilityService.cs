using AKA.CMS.Application.DTOs;
using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IFacilityService
{
    Task<IReadOnlyList<FacilityDto>> GetAllAsync(bool includeInactive = false);
    Task<FacilityDto> GetByIdAsync(int facilityId);
    Task<FacilityDto> CreateAsync(CreateFacilityRequest request, int performedBy, string ipAddress);
    Task<FacilityDto> UpdateAsync(int facilityId, UpdateFacilityRequest request, int performedBy, string ipAddress);
}

public interface IFacilityRepository
{
    Task<IReadOnlyList<Facility>> GetAllAsync(bool includeInactive);
    Task<Facility?> GetByIdAsync(int facilityId);
    Task<int> CreateAsync(Facility facility, int performedBy, string ipAddress);
    Task UpdateAsync(Facility facility, int performedBy, string ipAddress);
}
