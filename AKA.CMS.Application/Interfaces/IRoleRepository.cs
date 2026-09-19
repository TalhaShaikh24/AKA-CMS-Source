using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IRoleRepository
{
    Task<IReadOnlyList<Role>> GetAllAsync();
    Task<Role?> GetByIdAsync(int roleId);
    Task<int> CreateAsync(string description, int performedBy);
    Task<IReadOnlyList<ControllerAction>> GetPermissionsAsync(int roleId);
    Task AssignPermissionAsync(int roleId, int controllerActionId, string createdBy, int performedBy);
    Task RemovePermissionAsync(int roleId, int controllerActionId, int performedBy);
}
