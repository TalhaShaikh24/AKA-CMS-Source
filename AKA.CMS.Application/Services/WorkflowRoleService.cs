using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;

namespace AKA.CMS.Application.Services;

/// <summary>Workflow roles: the list of who a workflow step can wait
/// on, and which users hold each one. A workflow role is optional
/// for a user — a user with no workflow roles is unaffected, and a
/// step with no workflow role keeps working on its user role.</summary>
public sealed class WorkflowRoleService(
    IWorkflowRoleRepository roles,
    IUserService users) : IWorkflowRoleService
{
    public Task<IReadOnlyList<WorkflowRoleDto>> GetAllAsync()
        => roles.GetAllAsync();

    public async Task<WorkflowRoleDto> GetByIdAsync(int workflowRoleId)
        => await roles.GetByIdAsync(workflowRoleId)
            ?? throw new NotFoundException($"Workflow role {workflowRoleId} not found.");

    public async Task<WorkflowRoleDto> CreateAsync(SaveWorkflowRoleRequest request, int performedBy)
    {
        Validate(request);
        var id = await roles.SaveAsync(0, request, performedBy);
        return await GetByIdAsync(id);
    }

    public async Task<WorkflowRoleDto> UpdateAsync(int workflowRoleId, SaveWorkflowRoleRequest request, int performedBy)
    {
        _ = await GetByIdAsync(workflowRoleId);
        Validate(request);
        _ = await roles.SaveAsync(workflowRoleId, request, performedBy);
        return await GetByIdAsync(workflowRoleId);
    }

    public async Task DeleteAsync(int workflowRoleId, int performedBy)
    {
        _ = await GetByIdAsync(workflowRoleId);
        await roles.DeleteAsync(workflowRoleId, performedBy);
    }

    public async Task<IReadOnlyList<WorkflowRoleUserDto>> GetUsersByRoleAsync(int workflowRoleId)
    {
        _ = await GetByIdAsync(workflowRoleId);
        return await roles.GetUsersByRoleAsync(workflowRoleId);
    }

    public async Task SaveUsersByRoleAsync(int workflowRoleId, IReadOnlyList<int> userIds, int performedBy)
    {
        _ = await GetByIdAsync(workflowRoleId);
        var knownIds = new HashSet<int>((await users.GetAllAsync()).Select(u => u.UserId));
        var unknown = userIds.Where(id => !knownIds.Contains(id)).ToList();
        if (unknown.Count > 0)
            throw new InvalidDomainValueException($"User {unknown[0]} is not a real user.");
        await roles.SaveUsersByRoleAsync(workflowRoleId, userIds, performedBy);
    }

    public Task<IReadOnlyList<UserWorkflowRoleDto>> GetByUserAsync(int userId)
        => roles.GetByUserAsync(userId);

    private static void Validate(SaveWorkflowRoleRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.WorkflowRoleCode))
            throw new InvalidDomainValueException("Workflow role code is required.");
        if (string.IsNullOrWhiteSpace(request.Title))
            throw new InvalidDomainValueException("Workflow role title is required.");
    }
}
