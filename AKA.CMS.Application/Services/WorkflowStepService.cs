using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;

namespace AKA.CMS.Application.Services;

/// <summary>Workflow steps and their per-step sections and buttons
/// (DZ_ChildCareV3 tbl_WorkFlowSteps / StepSectionPermission /
/// Step_Actions). A step belongs to one workflow; its buttons move
/// an instance to the next step and the next role.</summary>
public sealed class WorkflowStepService(
    IWorkflowStepRepository steps,
    IWorkflowRepository workflows,
    IDynamicFormRepository forms,
    IRoleService roles) : IWorkflowStepService
{
    public async Task<IReadOnlyList<WorkflowStepDto>> GetByWorkflowAsync(int workflowId)
    {
        _ = await EnsureWorkflowAsync(workflowId);
        return await steps.GetByWorkflowAsync(workflowId);
    }

    public async Task<WorkflowStepDto> GetByIdAsync(int stepId)
        => await steps.GetByIdAsync(stepId)
            ?? throw new NotFoundException($"Step {stepId} not found.");

    public async Task<WorkflowStepDto> CreateAsync(int workflowId, SaveWorkflowStepRequest request, int performedBy)
    {
        _ = await EnsureWorkflowAsync(workflowId);
        await ValidateStepAsync(request);
        var id = await steps.SaveStepAsync(0, workflowId, request, performedBy);
        return await GetByIdAsync(id);
    }

    public async Task<WorkflowStepDto> UpdateAsync(int stepId, SaveWorkflowStepRequest request, int performedBy)
    {
        var existing = await GetByIdAsync(stepId);
        await ValidateStepAsync(request);
        _ = await steps.SaveStepAsync(stepId, existing.WorkflowId, request, performedBy);
        return await GetByIdAsync(stepId);
    }

    public async Task DeleteAsync(int stepId, int performedBy)
    {
        _ = await GetByIdAsync(stepId);
        await steps.DeleteStepAsync(stepId, performedBy);
    }

    public async Task<IReadOnlyList<WorkflowStepSectionDto>> GetSectionsByStepAsync(int stepId)
    {
        _ = await GetByIdAsync(stepId);
        return await steps.GetSectionsByStepAsync(stepId);
    }

    public async Task SaveSectionsAsync(int stepId, IReadOnlyList<SaveWorkflowStepSectionRequest> sections, int performedBy)
    {
        var step = await GetByIdAsync(stepId);
        var workflow = await EnsureWorkflowAsync(step.WorkflowId);
        var form = await forms.GetByIdAsync(workflow.FormId)
            ?? throw new NotFoundException($"Form {workflow.FormId} not found.");
        var formSections = new HashSet<string>(
            form.Fields.Where(f => f.FieldType == "section").Select(f => f.FieldKey),
            StringComparer.OrdinalIgnoreCase);
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var section in sections)
        {
            if (string.IsNullOrWhiteSpace(section.SectionKey))
                throw new InvalidDomainValueException("Each step section needs a section key.");
            if (!formSections.Contains(section.SectionKey))
                throw new InvalidDomainValueException($"Section '{section.SectionKey}' is not a section of this form.");
            if (!seen.Add(section.SectionKey.Trim()))
                throw new InvalidDomainValueException($"Duplicate step section '{section.SectionKey}'.");
            if (section.DisplayOrder < 0)
                throw new InvalidDomainValueException($"Section '{section.SectionKey}' display order must be 0 or more.");
        }
        await steps.SaveSectionsAsync(stepId, sections, performedBy);
    }

    public async Task<IReadOnlyList<WorkflowStepActionDto>> GetActionsByStepAsync(int stepId)
    {
        _ = await GetByIdAsync(stepId);
        return await steps.GetActionsByStepAsync(stepId);
    }

    public async Task SaveActionsAsync(int stepId, IReadOnlyList<SaveWorkflowStepActionRequest> actions, int performedBy)
    {
        var step = await GetByIdAsync(stepId);
        var workflowSteps = await steps.GetByWorkflowAsync(step.WorkflowId);
        var stepCodes = new HashSet<string>(
            workflowSteps.Select(s => s.StepCode), StringComparer.OrdinalIgnoreCase);
        var roleIds = new HashSet<int>((await roles.GetAllAsync()).Select(r => r.RoleId));
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var action in actions)
        {
            if (string.IsNullOrWhiteSpace(action.ActionCode))
                throw new InvalidDomainValueException("Each button needs an action code.");
            if (string.IsNullOrWhiteSpace(action.ActionTitle))
                throw new InvalidDomainValueException($"Button '{action.ActionCode}' needs a title.");
            if (!seen.Add(action.ActionCode.Trim()))
                throw new InvalidDomainValueException($"Duplicate button code '{action.ActionCode}'.");
            // The next step must be a step of the same workflow — a
            // typo must fail here with 400, not strand the request.
            if (string.IsNullOrWhiteSpace(action.NextStepCode) || !stepCodes.Contains(action.NextStepCode))
                throw new InvalidDomainValueException(
                    $"Button '{action.ActionCode}' next step '{action.NextStepCode}' is not a step of this workflow.");
            if (!string.Equals(action.NextAssignmentType, "Static", StringComparison.OrdinalIgnoreCase))
                throw new InvalidDomainValueException(
                    $"Button '{action.ActionCode}' assignment type must be 'Static'.");
            if (action.NextRoleID is not null && !roleIds.Contains(action.NextRoleID.Value))
                throw new InvalidDomainValueException(
                    $"Button '{action.ActionCode}' next role {action.NextRoleID} is not a real role.");
            if (action.DisplayOrder < 0)
                throw new InvalidDomainValueException($"Button '{action.ActionCode}' display order must be 0 or more.");
        }
        await steps.SaveActionsAsync(stepId, actions, performedBy);
    }

    private async Task<WorkflowDetailDto> EnsureWorkflowAsync(int workflowId)
        => await workflows.GetByIdAsync(workflowId)
            ?? throw new NotFoundException($"Workflow {workflowId} not found.");

    private async Task ValidateStepAsync(SaveWorkflowStepRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.StepCode))
            throw new InvalidDomainValueException("Step code is required.");
        if (string.IsNullOrWhiteSpace(request.StepTitle))
            throw new InvalidDomainValueException("Step title is required.");
        if (request.SLA is < 0)
            throw new InvalidDomainValueException("SLA days must be 0 or more.");
        if (request.DisplayOrder < 0)
            throw new InvalidDomainValueException("Display order must be 0 or more.");
        if (request.ResponsibleRoleID is not null)
        {
            var roleIds = new HashSet<int>((await roles.GetAllAsync()).Select(r => r.RoleId));
            if (!roleIds.Contains(request.ResponsibleRoleID.Value))
                throw new InvalidDomainValueException($"Role {request.ResponsibleRoleID} is not a real role.");
        }
    }
}
