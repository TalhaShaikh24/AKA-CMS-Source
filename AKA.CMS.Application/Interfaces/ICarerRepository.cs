using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface ICarerRepository
{
    Task<int> AddAsync(int caseId, string fullName, string? relationship, string? phone,
        bool isPrimary, int performedBy, string ipAddress);
    Task UpdateAsync(int carerId, int caseId, string fullName, string? relationship,
        string? phone, bool isPrimary, byte[] rowVersion, int performedBy, string ipAddress);
    Task DeactivateAsync(int carerId, int caseId, byte[] rowVersion, int performedBy, string ipAddress);
    Task<IReadOnlyList<Carer>> GetByCaseAsync(int caseId);
}
