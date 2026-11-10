using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IWorkflowRoleRepository
{
    Task<IReadOnlyList<WorkflowRoleDto>> GetAllAsync();
    Task<WorkflowRoleDto?> GetByIdAsync(int workflowRoleId);
    Task<int> SaveAsync(int workflowRoleId, SaveWorkflowRoleRequest request, int performedBy);
    Task DeleteAsync(int workflowRoleId, int performedBy);
    Task<IReadOnlyList<WorkflowRoleUserDto>> GetUsersByRoleAsync(int workflowRoleId);
    Task SaveUsersByRoleAsync(int workflowRoleId, IReadOnlyList<int> userIds, int performedBy);
    Task<IReadOnlyList<UserWorkflowRoleDto>> GetByUserAsync(int userId);
}

public interface IWorkflowRoleService
{
    Task<IReadOnlyList<WorkflowRoleDto>> GetAllAsync();
    Task<WorkflowRoleDto> GetByIdAsync(int workflowRoleId);
    Task<WorkflowRoleDto> CreateAsync(SaveWorkflowRoleRequest request, int performedBy);
    Task<WorkflowRoleDto> UpdateAsync(int workflowRoleId, SaveWorkflowRoleRequest request, int performedBy);
    Task DeleteAsync(int workflowRoleId, int performedBy);
    Task<IReadOnlyList<WorkflowRoleUserDto>> GetUsersByRoleAsync(int workflowRoleId);
    Task SaveUsersByRoleAsync(int workflowRoleId, IReadOnlyList<int> userIds, int performedBy);
    Task<IReadOnlyList<UserWorkflowRoleDto>> GetByUserAsync(int userId);
}
