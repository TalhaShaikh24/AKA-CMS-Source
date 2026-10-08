using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using AKA.CMS.Domain.Entities;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class TaskService(
    ITaskRepository taskRepository,
    IValidator<CreateTaskRequest> createValidator,
    IValidator<UpdateTaskStatusRequest> statusValidator,
    IValidator<AssignTaskRequest> assignValidator) : ITaskService
{
    private static readonly string[] ValidTabs = ["All", "DueToday", "Overdue"];

    public async Task<IReadOnlyList<TaskDto>> GetAllAsync(
        string tab = "All", int? caseId = null, int? assignedToUserId = null)
    {
        var normalizedTab = ValidTabs.Contains(tab) ? tab : "All";
        var tasks = await taskRepository.GetAllAsync(normalizedTab, caseId, assignedToUserId);
        return tasks.Select(t => t.ToDto()).ToList();
    }

    public async Task<TaskDto> GetByIdAsync(int taskId)
    {
        var task = await taskRepository.GetByIdAsync(taskId)
            ?? throw new NotFoundException($"Task {taskId} not found.");
        return task.ToDto();
    }

    public async Task<TaskDto> CreateAsync(
        CreateTaskRequest request, int performedBy, string ipAddress)
    {
        await createValidator.ValidateAndThrowAsync(request);

        var taskId = await taskRepository.CreateAsync(
            new TaskItem
            {
                Title = request.Title,
                Description = request.Description,
                CaseId = request.CaseId,
                TaskType = string.IsNullOrWhiteSpace(request.TaskType) ? "General" : request.TaskType,
                Priority = request.Priority,
                DueDate = request.DueDate.ToDateTime(TimeOnly.MinValue),
                AssignedToRoleId = request.AssignedToRoleId,
                AssignedToUserId = request.AssignedToUserId,
                NotifyRecipients = request.NotifyRecipients,
                Status = "Pending"
            },
            performedBy,
            ipAddress);

        return await GetByIdAsync(taskId);
    }

    public async Task<TaskDto> UpdateStatusAsync(
        int taskId, UpdateTaskStatusRequest request, int performedBy, string ipAddress)
    {
        await statusValidator.ValidateAndThrowAsync(request);
        await taskRepository.UpdateStatusAsync(
            taskId, request.Status, request.RowVersion, performedBy, ipAddress);
        return await GetByIdAsync(taskId);
    }

    public async Task<TaskDto> AssignAsync(
        int taskId, AssignTaskRequest request, int performedBy, string ipAddress)
    {
        await assignValidator.ValidateAndThrowAsync(request);
        await taskRepository.AssignAsync(
            taskId, request.AssignedToRoleId, request.AssignedToUserId,
            request.RowVersion, performedBy, ipAddress);
        return await GetByIdAsync(taskId);
    }
}
