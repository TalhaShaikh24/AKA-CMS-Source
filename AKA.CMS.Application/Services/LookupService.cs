using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;

namespace AKA.CMS.Application.Services;

public sealed class LookupService(ILookupRepository lookupRepository) : ILookupService
{
    public async Task<IReadOnlyList<LookupItemDto>> GetByTypeAsync(string lookupType)
    {
        var items = await lookupRepository.GetByTypeAsync(lookupType);
        return items.Select(i => i.ToDto()).ToList();
    }
}
