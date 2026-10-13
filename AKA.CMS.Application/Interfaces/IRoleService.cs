using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IRoleService
{
    Task<IReadOnlyList<RoleDto>> GetAllAsync();
    Task<RoleDto> GetByIdAsync(int roleId);
    Task<RoleDto> CreateAsync(CreateRoleRequest request, int performedBy);
    Task<RoleDto> UpdateAsync(int roleId, UpdateRoleRequest request, int performedBy);
    Task<IReadOnlyList<PermissionDto>> GetPermissionsAsync(int roleId);
    Task AssignPermissionAsync(int roleId, AssignPermissionRequest request, int performedBy, string performedByName);
    Task RemovePermissionAsync(int roleId, int controllerActionId, int performedBy);
}
