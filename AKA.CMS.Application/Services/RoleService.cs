using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using AKA.CMS.Application.Validators;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class RoleService(
    IRoleRepository roleRepository,
    IValidator<AssignPermissionRequest> assignPermissionValidator,
    IValidator<CreateRoleRequest> createRoleValidator) : IRoleService
{
    public async Task<IReadOnlyList<RoleDto>> GetAllAsync()
    {
        var roles = await roleRepository.GetAllAsync();
        return roles.Select(r => r.ToDto()).ToList();
    }

    public async Task<RoleDto> GetByIdAsync(int roleId)
    {
        var role = await roleRepository.GetByIdAsync(roleId)
            ?? throw new NotFoundException($"Role {roleId} not found.");
        return role.ToDto();
    }

    public async Task<RoleDto> CreateAsync(CreateRoleRequest request, int performedBy)
    {
        await createRoleValidator.ValidateAndThrowAsync(request);
        var roleId = await roleRepository.CreateAsync(request.Description, performedBy);
        return await GetByIdAsync(roleId);
    }

    public async Task<RoleDto> UpdateAsync(int roleId, UpdateRoleRequest request, int performedBy)
    {
        await new UpdateRoleRequestValidator().ValidateAndThrowAsync(request);
        await roleRepository.UpdateAsync(roleId, request.Description, performedBy);
        return await GetByIdAsync(roleId);
    }

    public async Task<IReadOnlyList<PermissionDto>> GetPermissionsAsync(int roleId)
    {
        _ = await roleRepository.GetByIdAsync(roleId)
            ?? throw new NotFoundException($"Role {roleId} not found.");
        var permissions = await roleRepository.GetPermissionsAsync(roleId);
        return permissions.Select(p => p.ToDto()).ToList();
    }

    public async Task AssignPermissionAsync(int roleId, AssignPermissionRequest request, int performedBy, string performedByName)
    {
        await assignPermissionValidator.ValidateAndThrowAsync(request);

        _ = await roleRepository.GetByIdAsync(roleId)
            ?? throw new NotFoundException($"Role {roleId} not found.");
        await roleRepository.AssignPermissionAsync(roleId, request.ControllerActionId, performedByName, performedBy);
    }

    public async Task RemovePermissionAsync(int roleId, int controllerActionId, int performedBy)
    {
        _ = await roleRepository.GetByIdAsync(roleId)
            ?? throw new NotFoundException($"Role {roleId} not found.");
        await roleRepository.RemovePermissionAsync(roleId, controllerActionId, performedBy);
    }
}
