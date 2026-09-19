using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IPermissionRepository
{
    Task<IReadOnlyList<ControllerAction>> GetCatalogAsync();
}
