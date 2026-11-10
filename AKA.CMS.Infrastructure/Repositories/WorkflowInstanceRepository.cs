using System.Data;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class WorkflowInstanceRepository(DapperContext context) : IWorkflowInstanceRepository
{
    private sealed class InstanceRow
    {
        public int WorkflowInstanceId { get; set; }
        public int WorkflowId { get; set; }
        public string WorkflowName { get; set; } = string.Empty;
        public string? WorkflowCode { get; set; }
        public int FormId { get; set; }
        public string FormKey { get; set; } = string.Empty;
        public string FormTitle { get; set; } = string.Empty;
        public int? SubmissionId { get; set; }
        public string CurrentStepCode { get; set; } = string.Empty;
        public string? CurrentStepTitle { get; set; }
        public bool IsEndStep { get; set; }
        public int? CurrentRoleID { get; set; }
        public string? CurrentRoleName { get; set; }
        public int? CurrentWorkflowRoleID { get; set; }
        public string? CurrentWorkflowRoleName { get; set; }
        public int? CurrentUserID { get; set; }
        public int? SLA_NoOfDays { get; set; }
        public DateTime? SLA_Date { get; set; }
        public int? Stage { get; set; }
        public string? Comments { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }

    private sealed class LogRow
    {
        public int WorkflowInstanceLogId { get; set; }
        public int WorkflowInstanceId { get; set; }
        public string CurrentStepCode { get; set; } = string.Empty;
        public string? CurrentStepTitle { get; set; }
        public int? CurrentRoleID { get; set; }
        public string? CurrentRoleName { get; set; }
        public int? CurrentWorkflowRoleID { get; set; }
        public string? CurrentWorkflowRoleName { get; set; }
        public int? CurrentUserID { get; set; }
        public int? SLA_NoOfDays { get; set; }
        public DateTime? SLA_Date { get; set; }
        public int? Stage { get; set; }
        public string? Comments { get; set; }
        public DateTime LogDate { get; set; }
        public string? Status { get; set; }
    }

    private sealed class ActionsStepRow
    {
        public int WorkflowStepId { get; set; }
        public string StepCode { get; set; } = string.Empty;
        public string StepTitle { get; set; } = string.Empty;
        public bool IsStart { get; set; }
        public bool IsEnd { get; set; }
    }

    private sealed class ActionsRow
    {
        public int WorkflowStepActionId { get; set; }
        public int WorkflowStepId { get; set; }
        public string ActionCode { get; set; } = string.Empty;
        public string ActionTitle { get; set; } = string.Empty;
        public string NextStepCode { get; set; } = string.Empty;
        public string? NextStepTitle { get; set; }
        public string NextAssignmentType { get; set; } = "Static";
        public int? NextRoleID { get; set; }
        public string? NextRoleName { get; set; }
        public int? NextWorkflowRoleID { get; set; }
        public string? NextWorkflowRoleName { get; set; }
        public bool SaveOrMove { get; set; }
        public bool IsSendEmail { get; set; }
        public int DisplayOrder { get; set; }
    }

    public async Task<int> StartAsync(int workflowId, int? submissionId, string? comments, int performedBy)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@WorkflowId", workflowId);
        p.Add("@SubmissionId", submissionId);
        p.Add("@Comments", comments);
        p.Add("@PerformedBy", performedBy);
        try
        {
            return await connection.QuerySingleAsync<int>(
                StoredProcedures.WorkflowInstanceStart, p, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50000)
        {
            // The SP validates (duplicate code, bad key, wrong step/action)
            // and THROWs 50000; surface it as a 400, not a 500.
            throw new InvalidDomainValueException(ex.Message);
        }

    }

    public async Task<WorkflowInstanceDto?> LinkSubmissionAsync(int instanceId, int submissionId)
    {
        using var connection = context.CreateConnection();
        try
        {
            var row = await connection.QuerySingleOrDefaultAsync<InstanceRow>(
                StoredProcedures.WorkflowInstanceLinkSubmission,
                new { WorkflowInstanceId = instanceId, SubmissionId = submissionId },
                commandType: CommandType.StoredProcedure);
            return row is null ? null : ToDto(row);
        }
        catch (SqlException ex) when (ex.Number == 50000)
        {
            throw new InvalidDomainValueException(ex.Message);
        }
    }

    public async Task<WorkflowInstanceDto?> GetByIdAsync(int instanceId)
    {
        using var connection = context.CreateConnection();
        var row = await connection.QuerySingleOrDefaultAsync<InstanceRow>(
            StoredProcedures.WorkflowInstanceGetById,
            new { WorkflowInstanceId = instanceId },
            commandType: CommandType.StoredProcedure);
        return row is null ? null : ToDto(row);
    }

    public async Task<IReadOnlyList<WorkflowInstanceDto>> GetMyTasksAsync(int userId)
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<InstanceRow>(
            StoredProcedures.WorkflowInstanceGetMyTasks,
            new { UserId = userId },
            commandType: CommandType.StoredProcedure);
        return rows.Select(ToDto).ToList();
    }

    public async Task<IReadOnlyList<WorkflowInstanceDto>> GetMyRequestsAsync(int userId)
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<InstanceRow>(
            StoredProcedures.WorkflowInstanceGetMyRequests,
            new { UserId = userId },
            commandType: CommandType.StoredProcedure);
        return rows.Select(ToDto).ToList();
    }

    public async Task<WorkflowInstanceDto?> ExecuteActionAsync(int instanceId, string actionCode, string? comments, int performedBy)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@WorkflowInstanceId", instanceId);
        p.Add("@ActionCode", actionCode);
        p.Add("@Comments", comments);
        p.Add("@PerformedBy", performedBy);
        // The SP ends by selecting the updated instance row.
        try
        {
            var row = await connection.QuerySingleOrDefaultAsync<InstanceRow>(
                StoredProcedures.WorkflowInstanceExecuteAction, p, commandType: CommandType.StoredProcedure);
            return row is null ? null : ToDto(row);
        }
        catch (SqlException ex) when (ex.Number == 50000)
        {
            // The SP validates (duplicate code, bad key, wrong step/action)
            // and THROWs 50000; surface it as a 400, not a 500.
            throw new InvalidDomainValueException(ex.Message);
        }

    }

    public async Task<IReadOnlyList<WorkflowInstanceLogDto>> GetLogAsync(int instanceId)
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<LogRow>(
            StoredProcedures.WorkflowInstanceGetLog,
            new { WorkflowInstanceId = instanceId },
            commandType: CommandType.StoredProcedure);
        return rows.Select(r => new WorkflowInstanceLogDto
        {
            WorkflowInstanceLogId = r.WorkflowInstanceLogId,
            WorkflowInstanceId = r.WorkflowInstanceId,
            CurrentStepCode = r.CurrentStepCode,
            CurrentStepTitle = r.CurrentStepTitle,
            CurrentRoleID = r.CurrentRoleID,
            CurrentRoleName = r.CurrentRoleName,
            CurrentWorkflowRoleID = r.CurrentWorkflowRoleID,
            CurrentWorkflowRoleName = r.CurrentWorkflowRoleName,
            CurrentUserID = r.CurrentUserID,
            SLA_NoOfDays = r.SLA_NoOfDays,
            SLA_Date = r.SLA_Date,
            Stage = r.Stage,
            Comments = r.Comments,
            LogDate = r.LogDate,
            Status = r.Status
        }).ToList();
    }

    public async Task<WorkflowStepActionsResponseDto?> GetActionsAsync(int instanceId)
    {
        using var connection = context.CreateConnection();
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.WorkflowInstanceGetActions,
            new { WorkflowInstanceId = instanceId },
            commandType: CommandType.StoredProcedure);
        var step = (await multi.ReadAsync<ActionsStepRow>()).FirstOrDefault();
        if (step is null) return null;
        var actions = (await multi.ReadAsync<ActionsRow>()).ToList();
        return new WorkflowStepActionsResponseDto
        {
            WorkflowStepId = step.WorkflowStepId,
            StepCode = step.StepCode,
            StepTitle = step.StepTitle,
            IsStart = step.IsStart,
            IsEnd = step.IsEnd,
            Actions = actions.Select(a => new WorkflowStepActionDto
            {
                WorkflowStepActionId = a.WorkflowStepActionId,
                WorkflowStepId = a.WorkflowStepId,
                ActionCode = a.ActionCode,
                ActionTitle = a.ActionTitle,
                NextStepCode = a.NextStepCode,
                NextStepTitle = a.NextStepTitle,
                NextAssignmentType = a.NextAssignmentType,
                NextRoleID = a.NextRoleID,
                NextRoleName = a.NextRoleName,
                NextWorkflowRoleID = a.NextWorkflowRoleID,
                NextWorkflowRoleName = a.NextWorkflowRoleName,
                SaveOrMove = a.SaveOrMove,
                IsSendEmail = a.IsSendEmail,
                DisplayOrder = a.DisplayOrder
            }).ToList()
        };
    }

    public async Task<(bool IsAdmin, IReadOnlyList<int> RoleIds, IReadOnlyList<int> WorkflowRoleIds)> GetUserAccessAsync(int userId)
    {
        using var connection = context.CreateConnection();
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.WorkflowInstanceGetUserAccess,
            new { UserId = userId },
            commandType: CommandType.StoredProcedure);
        var isAdmin = (await multi.ReadAsync<bool>()).FirstOrDefault();
        var roleIds = (await multi.ReadAsync<int>()).ToList();
        var workflowRoleIds = (await multi.ReadAsync<int>()).ToList();
        return (isAdmin, roleIds, workflowRoleIds);
    }

    private static WorkflowInstanceDto ToDto(InstanceRow r) => new()
    {
        WorkflowInstanceId = r.WorkflowInstanceId,
        WorkflowId = r.WorkflowId,
        WorkflowName = r.WorkflowName,
        WorkflowCode = r.WorkflowCode,
        FormId = r.FormId,
        FormKey = r.FormKey,
        FormTitle = r.FormTitle,
        SubmissionId = r.SubmissionId,
        CurrentStepCode = r.CurrentStepCode,
        CurrentStepTitle = r.CurrentStepTitle,
        IsEndStep = r.IsEndStep,
        CurrentRoleID = r.CurrentRoleID,
        CurrentRoleName = r.CurrentRoleName,
        CurrentWorkflowRoleID = r.CurrentWorkflowRoleID,
        CurrentWorkflowRoleName = r.CurrentWorkflowRoleName,
        CurrentUserID = r.CurrentUserID,
        SLA_NoOfDays = r.SLA_NoOfDays,
        SLA_Date = r.SLA_Date,
        Stage = r.Stage,
        Comments = r.Comments,
        CreatedAt = r.CreatedAt,
        UpdatedAt = r.UpdatedAt
    };
}
