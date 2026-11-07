using System.Data;
using System.Text.Json;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class WorkflowStepRepository(DapperContext context) : IWorkflowStepRepository
{
    private sealed class StepRow
    {
        public int WorkflowStepId { get; set; }
        public int WorkflowId { get; set; }
        public string StepCode { get; set; } = string.Empty;
        public string StepTitle { get; set; } = string.Empty;
        public int? ResponsibleRoleID { get; set; }
        public string? ResponsibleRoleName { get; set; }
        public bool IsStart { get; set; }
        public bool IsEnd { get; set; }
        public int? SLA { get; set; }
        public int DisplayOrder { get; set; }
        public bool IsActive { get; set; }
        public int StepActionCount { get; set; }
        public int StepSectionCount { get; set; }
    }

    private sealed class StepSectionRow
    {
        public int WorkflowStepSectionId { get; set; }
        public int WorkflowStepId { get; set; }
        public string SectionKey { get; set; } = string.Empty;
        public bool IsVisible { get; set; }
        public bool IsEnable { get; set; }
        public int DisplayOrder { get; set; }
    }

    private sealed class StepActionRow
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
        public bool SaveOrMove { get; set; }
        public bool IsSendEmail { get; set; }
        public int DisplayOrder { get; set; }
    }

    public async Task<IReadOnlyList<WorkflowStepDto>> GetByWorkflowAsync(int workflowId)
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<StepRow>(
            StoredProcedures.WorkflowStepGetByWorkflow,
            new { WorkflowId = workflowId },
            commandType: CommandType.StoredProcedure);
        return rows.Select(ToDto).ToList();
    }

    public async Task<WorkflowStepDto?> GetByIdAsync(int stepId)
    {
        using var connection = context.CreateConnection();
        var row = await connection.QuerySingleOrDefaultAsync<StepRow>(
            StoredProcedures.WorkflowStepGetById,
            new { WorkflowStepId = stepId },
            commandType: CommandType.StoredProcedure);
        return row is null ? null : ToDto(row);
    }

    public async Task<int> SaveStepAsync(int stepId, int workflowId, SaveWorkflowStepRequest request, int performedBy)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@WorkflowStepId", stepId);
        p.Add("@WorkflowId", workflowId);
        p.Add("@StepCode", request.StepCode);
        p.Add("@StepTitle", request.StepTitle);
        p.Add("@ResponsibleRoleID", request.ResponsibleRoleID);
        p.Add("@IsStart", request.IsStart);
        p.Add("@IsEnd", request.IsEnd);
        p.Add("@SLA", request.SLA);
        p.Add("@DisplayOrder", request.DisplayOrder);
        p.Add("@PerformedBy", performedBy);
        try
        {
            return await connection.QuerySingleAsync<int>(
                StoredProcedures.WorkflowStepSave, p, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50000)
        {
            // The SP validates (duplicate code, bad key, wrong step/action)
            // and THROWs 50000; surface it as a 400, not a 500.
            throw new InvalidDomainValueException(ex.Message);
        }

    }

    public async Task DeleteStepAsync(int stepId, int performedBy)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@WorkflowStepId", stepId);
        p.Add("@PerformedBy", performedBy);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.WorkflowStepDelete, p, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50000)
        {
            // The SP validates (duplicate code, bad key, wrong step/action)
            // and THROWs 50000; surface it as a 400, not a 500.
            throw new InvalidDomainValueException(ex.Message);
        }

    }

    public async Task<IReadOnlyList<WorkflowStepSectionDto>> GetSectionsByStepAsync(int stepId)
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<StepSectionRow>(
            StoredProcedures.WorkflowStepSectionsGetByStep,
            new { WorkflowStepId = stepId },
            commandType: CommandType.StoredProcedure);
        return rows.Select(r => new WorkflowStepSectionDto
        {
            WorkflowStepSectionId = r.WorkflowStepSectionId,
            WorkflowStepId = r.WorkflowStepId,
            SectionKey = r.SectionKey,
            IsVisible = r.IsVisible,
            IsEnable = r.IsEnable,
            DisplayOrder = r.DisplayOrder
        }).ToList();
    }

    public async Task SaveSectionsAsync(int stepId, IReadOnlyList<SaveWorkflowStepSectionRequest> sections, int performedBy)
    {
        var json = JsonSerializer.Serialize(sections.Select(s => new
        {
            sectionKey = s.SectionKey,
            isVisible = s.IsVisible,
            isEnable = s.IsEnable,
            displayOrder = s.DisplayOrder
        }));
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@WorkflowStepId", stepId);
        p.Add("@SectionsJson", json);
        p.Add("@PerformedBy", performedBy);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.WorkflowStepSectionsSave, p, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50000)
        {
            // The SP validates (duplicate code, bad key, wrong step/action)
            // and THROWs 50000; surface it as a 400, not a 500.
            throw new InvalidDomainValueException(ex.Message);
        }

    }

    public async Task<IReadOnlyList<WorkflowStepActionDto>> GetActionsByStepAsync(int stepId)
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<StepActionRow>(
            StoredProcedures.WorkflowStepActionsGetByStep,
            new { WorkflowStepId = stepId },
            commandType: CommandType.StoredProcedure);
        return rows.Select(ToActionDto).ToList();
    }

    public async Task SaveActionsAsync(int stepId, IReadOnlyList<SaveWorkflowStepActionRequest> actions, int performedBy)
    {
        var json = JsonSerializer.Serialize(actions.Select(a => new
        {
            actionCode = a.ActionCode,
            actionTitle = a.ActionTitle,
            nextStepCode = a.NextStepCode,
            nextAssignmentType = a.NextAssignmentType,
            nextRoleId = a.NextRoleID,
            saveOrMove = a.SaveOrMove,
            isSendEmail = a.IsSendEmail,
            displayOrder = a.DisplayOrder
        }));
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@WorkflowStepId", stepId);
        p.Add("@ActionsJson", json);
        p.Add("@PerformedBy", performedBy);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.WorkflowStepActionsSave, p, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50000)
        {
            // The SP validates (duplicate code, bad key, wrong step/action)
            // and THROWs 50000; surface it as a 400, not a 500.
            throw new InvalidDomainValueException(ex.Message);
        }

    }

    private static WorkflowStepDto ToDto(StepRow r) => new()
    {
        WorkflowStepId = r.WorkflowStepId,
        WorkflowId = r.WorkflowId,
        StepCode = r.StepCode,
        StepTitle = r.StepTitle,
        ResponsibleRoleID = r.ResponsibleRoleID,
        ResponsibleRoleName = r.ResponsibleRoleName,
        IsStart = r.IsStart,
        IsEnd = r.IsEnd,
        SLA = r.SLA,
        DisplayOrder = r.DisplayOrder,
        IsActive = r.IsActive,
        StepActionCount = r.StepActionCount,
        StepSectionCount = r.StepSectionCount
    };

    private static WorkflowStepActionDto ToActionDto(StepActionRow r) => new()
    {
        WorkflowStepActionId = r.WorkflowStepActionId,
        WorkflowStepId = r.WorkflowStepId,
        ActionCode = r.ActionCode,
        ActionTitle = r.ActionTitle,
        NextStepCode = r.NextStepCode,
        NextStepTitle = r.NextStepTitle,
        NextAssignmentType = r.NextAssignmentType,
        NextRoleID = r.NextRoleID,
        NextRoleName = r.NextRoleName,
        SaveOrMove = r.SaveOrMove,
        IsSendEmail = r.IsSendEmail,
        DisplayOrder = r.DisplayOrder
    };
}
