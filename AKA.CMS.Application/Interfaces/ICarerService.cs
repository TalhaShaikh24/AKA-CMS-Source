using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface ICarerService
{
    Task<CarerDto> AddAsync(AddCarerRequest request, int performedBy, string ipAddress);
    Task<CarerDto> UpdateAsync(int carerId, int caseId, UpdateCarerRequest request, int performedBy, string ipAddress);
    Task DeactivateAsync(int carerId, int caseId, byte[] rowVersion, int performedBy, string ipAddress);
    Task<IReadOnlyList<CarerDto>> GetByCaseAsync(int caseId);
}
