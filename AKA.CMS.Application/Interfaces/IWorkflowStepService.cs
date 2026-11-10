using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IWorkflowStepRepository
{
    Task<IReadOnlyList<WorkflowStepDto>> GetByWorkflowAsync(int workflowId);
    Task<WorkflowStepDto?> GetByIdAsync(int stepId);
    Task<int> SaveStepAsync(int stepId, int workflowId, SaveWorkflowStepRequest request, int performedBy);
    Task DeleteStepAsync(int stepId, int performedBy);
    Task<IReadOnlyList<WorkflowStepSectionDto>> GetSectionsByStepAsync(int stepId);
    Task SaveSectionsAsync(int stepId, IReadOnlyList<SaveWorkflowStepSectionRequest> sections, int performedBy);
    Task<IReadOnlyList<WorkflowStepActionDto>> GetActionsByStepAsync(int stepId);
    Task SaveActionsAsync(int stepId, IReadOnlyList<SaveWorkflowStepActionRequest> actions, int performedBy);
}

public interface IWorkflowInstanceRepository
{
    Task<int> StartAsync(int workflowId, int submissionId, string? comments, int performedBy);
    Task<WorkflowInstanceDto?> GetByIdAsync(int instanceId);
    Task<IReadOnlyList<WorkflowInstanceDto>> GetMyTasksAsync(int userId);
    Task<IReadOnlyList<WorkflowInstanceDto>> GetMyRequestsAsync(int userId);
    Task<WorkflowInstanceDto?> ExecuteActionAsync(int instanceId, string actionCode, string? comments, int performedBy);
    Task<IReadOnlyList<WorkflowInstanceLogDto>> GetLogAsync(int instanceId);
    Task<WorkflowStepActionsResponseDto?> GetActionsAsync(int instanceId);
    Task<(bool IsAdmin, IReadOnlyList<int> RoleIds, IReadOnlyList<int> WorkflowRoleIds)> GetUserAccessAsync(int userId);
}

public interface IWorkflowStepService
{
    Task<IReadOnlyList<WorkflowStepDto>> GetByWorkflowAsync(int workflowId);
    Task<WorkflowStepDto> GetByIdAsync(int stepId);
    Task<WorkflowStepDto> CreateAsync(int workflowId, SaveWorkflowStepRequest request, int performedBy);
    Task<WorkflowStepDto> UpdateAsync(int stepId, SaveWorkflowStepRequest request, int performedBy);
    Task DeleteAsync(int stepId, int performedBy);
    Task<IReadOnlyList<WorkflowStepSectionDto>> GetSectionsByStepAsync(int stepId);
    Task SaveSectionsAsync(int stepId, IReadOnlyList<SaveWorkflowStepSectionRequest> sections, int performedBy);
    Task<IReadOnlyList<WorkflowStepActionDto>> GetActionsByStepAsync(int stepId);
    Task SaveActionsAsync(int stepId, IReadOnlyList<SaveWorkflowStepActionRequest> actions, int performedBy);
}

public interface IWorkflowInstanceService
{
    Task<WorkflowInstanceDto> StartAsync(StartWorkflowInstanceRequest request, int performedBy);
    Task<WorkflowInstanceDto> GetByIdAsync(int instanceId);
    Task<IReadOnlyList<WorkflowInstanceDto>> GetMyTasksAsync(int userId);
    Task<IReadOnlyList<WorkflowInstanceDto>> GetMyRequestsAsync(int userId);
    Task<WorkflowInstanceDto> ExecuteActionAsync(int instanceId, string actionCode, string? comments, int userId);
    Task<IReadOnlyList<WorkflowInstanceLogDto>> GetLogAsync(int instanceId);
    Task<WorkflowStepActionsResponseDto> GetActionsAsync(int instanceId);
}
