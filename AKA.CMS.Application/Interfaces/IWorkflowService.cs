using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IWorkflowRepository
{
    Task<IReadOnlyList<WorkflowListItemDto>> GetAllAsync();
    Task<WorkflowDetailDto?> GetByIdAsync(int workflowId);
    Task<int> SaveAsync(int workflowId, SaveWorkflowRequest request, int performedBy);
    Task DeleteAsync(int workflowId, int performedBy);
    Task<WorkflowSectionsResponseDto> GetSectionsByFormAsync(int formId);
}

public interface IWorkflowService
{
    Task<IReadOnlyList<WorkflowListItemDto>> GetAllAsync();
    Task<WorkflowDetailDto> GetByIdAsync(int workflowId);
    Task<WorkflowDetailDto> CreateAsync(SaveWorkflowRequest request, int performedBy);
    Task<WorkflowDetailDto> UpdateAsync(int workflowId, SaveWorkflowRequest request, int performedBy);
    Task DeleteAsync(int workflowId, int performedBy);

    /// <summary>The Get Workflow Sections API: the form's active
    /// workflow's sections and actions. Empty sections means no
    /// active workflow, and the form shows everything.</summary>
    Task<WorkflowSectionsResponseDto> GetSectionsByFormAsync(int formId);
}
