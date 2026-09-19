using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface ILookupRepository
{
    Task<IReadOnlyList<LookupItem>> GetByTypeAsync(string lookupType);
}
