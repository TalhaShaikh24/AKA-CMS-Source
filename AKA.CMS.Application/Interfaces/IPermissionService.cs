using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IPermissionService
{
    Task<IReadOnlyList<PermissionDto>> GetCatalogAsync();
}
