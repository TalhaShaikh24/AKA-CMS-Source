namespace AKA.CMS.Application.DTOs;

public sealed record TaskDto(
    int TaskId,
    string Title,
    string? Description,
    int CaseId,
    string CaseNumber,
    string? PatientName,
    string TaskType,
    string Priority,
    DateOnly DueDate,
    int? AssignedToRoleId,
    string? AssignedRoleName,
    int? AssignedToUserId,
    string? AssignedUserName,
    string? NotifyRecipients,
    string Status,
    DateTime? CompletedAt,
    byte[] RowVersion);

public sealed record CreateTaskRequest(
    string Title,
    string? Description,
    int CaseId,
    string? TaskType,
    string Priority,
    DateOnly DueDate,
    int? AssignedToRoleId,
    int? AssignedToUserId,
    string? NotifyRecipients);

public sealed record UpdateTaskStatusRequest(
    string Status,
    byte[] RowVersion);

public sealed record AssignTaskRequest(
    int? AssignedToRoleId,
    int? AssignedToUserId,
    byte[] RowVersion);
