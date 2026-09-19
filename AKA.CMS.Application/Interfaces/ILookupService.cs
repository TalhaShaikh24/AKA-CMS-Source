using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface ILookupService
{
    Task<IReadOnlyList<LookupItemDto>> GetByTypeAsync(string lookupType);
}
