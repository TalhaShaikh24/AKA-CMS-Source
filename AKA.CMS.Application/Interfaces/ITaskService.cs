using AKA.CMS.Application.DTOs;
using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface ITaskService
{
    Task<IReadOnlyList<TaskDto>> GetAllAsync(string tab = "All", int? caseId = null, int? assignedToUserId = null);
    Task<TaskDto> GetByIdAsync(int taskId);
    Task<TaskDto> CreateAsync(CreateTaskRequest request, int performedBy, string ipAddress);
    Task<TaskDto> UpdateStatusAsync(int taskId, UpdateTaskStatusRequest request, int performedBy, string ipAddress);
    Task<TaskDto> AssignAsync(int taskId, AssignTaskRequest request, int performedBy, string ipAddress);
}

public interface ITaskRepository
{
    Task<IReadOnlyList<TaskItem>> GetAllAsync(string tab, int? caseId, int? assignedToUserId);
    Task<TaskItem?> GetByIdAsync(int taskId);
    Task<int> CreateAsync(TaskItem task, int performedBy, string ipAddress);
    Task UpdateStatusAsync(int taskId, string status, byte[] rowVersion, int performedBy, string ipAddress);
    Task AssignAsync(int taskId, int? roleId, int? userId, byte[] rowVersion, int performedBy, string ipAddress);
}
