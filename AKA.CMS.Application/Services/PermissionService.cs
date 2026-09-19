using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;

namespace AKA.CMS.Application.Services;

public sealed class PermissionService(IPermissionRepository permissionRepository) : IPermissionService
{
    public async Task<IReadOnlyList<PermissionDto>> GetCatalogAsync()
    {
        var catalog = await permissionRepository.GetCatalogAsync();
        return catalog.Select(c => c.ToDto()).ToList();
    }
}
