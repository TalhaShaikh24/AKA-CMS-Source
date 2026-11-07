using System.Data;
using System.Text.Json;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class WorkflowRepository(DapperContext context) : IWorkflowRepository
{
    private sealed class HeaderRow
    {
        public int WorkflowId { get; set; }
        public string WorkflowName { get; set; } = string.Empty;
        public string? WorkflowCode { get; set; }
        public int FormId { get; set; }
        public string FormKey { get; set; } = string.Empty;
        public string FormTitle { get; set; } = string.Empty;
        public string? Description { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
        public int SectionCount { get; set; }
    }

    private sealed class SectionRow
    {
        public int WorkflowSectionId { get; set; }
        public int WorkflowId { get; set; }
        public string SectionKey { get; set; } = string.Empty;
        public bool IsVisible { get; set; }
        public bool IsEnable { get; set; } = true;
        public int DisplayOrder { get; set; }
        public bool IsActive { get; set; }
    }

    private sealed class ActionRow
    {
        public int WorkflowActionId { get; set; }
        public int WorkflowSectionId { get; set; }
        public string SectionKey { get; set; } = string.Empty;
        public string ActionType { get; set; } = string.Empty;
        public string? TargetKey { get; set; }
        public int SortOrder { get; set; }
        public bool IsActive { get; set; }
    }

    public async Task<IReadOnlyList<WorkflowListItemDto>> GetAllAsync()
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<HeaderRow>(
            StoredProcedures.WorkflowGetAll, commandType: CommandType.StoredProcedure);
        return rows.Select(r => new WorkflowListItemDto
        {
            WorkflowId = r.WorkflowId,
            WorkflowName = r.WorkflowName,
            WorkflowCode = r.WorkflowCode,
            FormId = r.FormId,
            FormKey = r.FormKey,
            FormTitle = r.FormTitle,
            IsActive = r.IsActive,
            SectionCount = r.SectionCount
        }).ToList();
    }

    public async Task<WorkflowDetailDto?> GetByIdAsync(int workflowId)
    {
        using var connection = context.CreateConnection();
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.WorkflowGetById,
            new { WorkflowId = workflowId },
            commandType: CommandType.StoredProcedure);
        var header = (await multi.ReadAsync<HeaderRow>()).FirstOrDefault();
        if (header is null) return null;
        var sections = (await multi.ReadAsync<SectionRow>()).ToList();
        var actions = (await multi.ReadAsync<ActionRow>()).ToList();
        return ToDetail(header, sections, actions);
    }

    public async Task<int> SaveAsync(int workflowId, SaveWorkflowRequest request, int performedBy)
    {
        // Sections go as one JSON document, actions nested inside
        // each section — the SP replaces them wholesale.
        var sectionsJson = JsonSerializer.Serialize(request.Sections.Select(s => new
        {
            sectionKey = s.SectionKey,
            isVisible = s.IsVisible,
            displayOrder = s.DisplayOrder,
            actions = s.Actions.Select(a => new
            {
                actionType = a.ActionType,
                targetKey = a.TargetKey,
                sortOrder = a.SortOrder
            })
        }));
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@WorkflowId", workflowId);
        p.Add("@WorkflowName", request.WorkflowName);
        p.Add("@WorkflowCode", request.WorkflowCode);
        p.Add("@FormId", request.FormId);
        p.Add("@Description", request.Description);
        p.Add("@IsActive", request.IsActive);
        p.Add("@SectionsJson", sectionsJson);
        p.Add("@PerformedBy", performedBy);
        try
        {
            return await connection.QuerySingleAsync<int>(
                StoredProcedures.WorkflowSave, p, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50000)
        {
            // The SP validates (duplicate code, bad key, wrong step/action)
            // and THROWs 50000; surface it as a 400, not a 500.
            throw new InvalidDomainValueException(ex.Message);
        }

    }

    public async Task DeleteAsync(int workflowId, int performedBy)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@WorkflowId", workflowId);
        p.Add("@PerformedBy", performedBy);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.WorkflowDelete, p, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50000)
        {
            // The SP validates (duplicate code, bad key, wrong step/action)
            // and THROWs 50000; surface it as a 400, not a 500.
            throw new InvalidDomainValueException(ex.Message);
        }

    }

    public async Task<WorkflowSectionsResponseDto> GetSectionsByFormAsync(int formId, int? instanceId = null)
    {
        using var connection = context.CreateConnection();
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.WorkflowGetSectionsByForm,
            new { FormId = formId, InstanceId = instanceId },
            commandType: CommandType.StoredProcedure);
        var workflowId = (await multi.ReadAsync<int?>()).FirstOrDefault();
        var sections = (await multi.ReadAsync<SectionRow>()).ToList();
        var actions = (await multi.ReadAsync<ActionRow>()).ToList();
        return new WorkflowSectionsResponseDto
        {
            WorkflowId = workflowId,
            Sections = sections.Select(s => new WorkflowSectionDto
            {
                SectionKey = s.SectionKey,
                IsVisible = s.IsVisible,
                IsEnable = s.IsEnable,
                DisplayOrder = s.DisplayOrder,
                Actions = actions
                    .Where(a => string.Equals(a.SectionKey, s.SectionKey, StringComparison.OrdinalIgnoreCase))
                    .OrderBy(a => a.SortOrder)
                    .Select(a => new WorkflowActionDto
                    {
                        WorkflowActionId = a.WorkflowActionId,
                        SectionKey = a.SectionKey,
                        ActionType = a.ActionType,
                        TargetKey = a.TargetKey,
                        SortOrder = a.SortOrder
                    }).ToList()
            }).ToList()
        };
    }

    private static WorkflowDetailDto ToDetail(HeaderRow header, List<SectionRow> sections, List<ActionRow> actions)
        => new()
        {
            WorkflowId = header.WorkflowId,
            WorkflowName = header.WorkflowName,
            WorkflowCode = header.WorkflowCode,
            FormId = header.FormId,
            FormKey = header.FormKey,
            FormTitle = header.FormTitle,
            Description = header.Description,
            IsActive = header.IsActive,
            Sections = sections.Select(s => new WorkflowSectionDto
            {
                SectionKey = s.SectionKey,
                IsVisible = s.IsVisible,
                IsEnable = s.IsEnable,
                DisplayOrder = s.DisplayOrder,
                Actions = actions
                    .Where(a => a.WorkflowSectionId == s.WorkflowSectionId)
                    .OrderBy(a => a.SortOrder)
                    .Select(a => new WorkflowActionDto
                    {
                        WorkflowActionId = a.WorkflowActionId,
                        SectionKey = a.SectionKey,
                        ActionType = a.ActionType,
                        TargetKey = a.TargetKey,
                        SortOrder = a.SortOrder
                    }).ToList()
            }).ToList()
        };
}
