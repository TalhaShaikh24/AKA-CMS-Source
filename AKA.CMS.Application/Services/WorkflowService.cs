using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;

namespace AKA.CMS.Application.Services;

/// <summary>Form-section Workflow (boss request 2026-11-05). A workflow
/// belongs to one Dynamic Form; on load, the form asks Get Workflow
/// Sections which sections show and which hide. Only one workflow
/// per form is active at a time — the save SP enforces that.</summary>
public sealed class WorkflowService(IWorkflowRepository repository, IDynamicFormRepository forms) : IWorkflowService
{
    private static readonly string[] ActionTypes =
        { "Show", "Hide", "Disable", "Enable", "Require", "MakeOptional" };

    public Task<IReadOnlyList<WorkflowListItemDto>> GetAllAsync()
        => repository.GetAllAsync();

    public async Task<WorkflowDetailDto> GetByIdAsync(int workflowId)
        => await repository.GetByIdAsync(workflowId)
            ?? throw new NotFoundException($"Workflow {workflowId} not found.");

    public async Task<WorkflowDetailDto> CreateAsync(SaveWorkflowRequest request, int performedBy)
    {
        var form = await EnsureFormExistsAsync(request.FormId);
        Validate(request, form);
        var id = await repository.SaveAsync(0, request, performedBy);
        return await GetByIdAsync(id);
    }

    public async Task<WorkflowDetailDto> UpdateAsync(int workflowId, SaveWorkflowRequest request, int performedBy)
    {
        _ = await GetByIdAsync(workflowId);
        var form = await EnsureFormExistsAsync(request.FormId);
        Validate(request, form);
        var id = await repository.SaveAsync(workflowId, request, performedBy);
        return await GetByIdAsync(id);
    }

    public async Task DeleteAsync(int workflowId, int performedBy)
    {
        _ = await GetByIdAsync(workflowId);
        await repository.DeleteAsync(workflowId, performedBy);
    }

    public async Task<WorkflowSectionsResponseDto> GetSectionsByFormAsync(int formId)
    {
        await EnsureFormExistsAsync(formId);
        return await repository.GetSectionsByFormAsync(formId);
    }

    private async Task<DynamicFormDetailDto> EnsureFormExistsAsync(int formId)
        => await forms.GetByIdAsync(formId)
            ?? throw new NotFoundException($"Form {formId} not found.");

    private static void Validate(SaveWorkflowRequest request, DynamicFormDetailDto form)
    {
        if (string.IsNullOrWhiteSpace(request.WorkflowName))
            throw new InvalidDomainValueException("Workflow name is required.");
        // A section key must be a real section of this form — a typo
        // must fail here with 400, not silently hide nothing on load.
        var formSections = new HashSet<string>(
            form.Fields.Where(f => f.FieldType == "section").Select(f => f.FieldKey),
            StringComparer.OrdinalIgnoreCase);
        var seenSections = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var section in request.Sections)
        {
            if (string.IsNullOrWhiteSpace(section.SectionKey))
                throw new InvalidDomainValueException("Each workflow section needs a section key.");
            if (!formSections.Contains(section.SectionKey))
                throw new InvalidDomainValueException($"Section '{section.SectionKey}' is not a section of this form.");
            if (!seenSections.Add(section.SectionKey.Trim()))
                throw new InvalidDomainValueException($"Duplicate workflow section '{section.SectionKey}'.");
            if (section.DisplayOrder < 0)
                throw new InvalidDomainValueException($"Section '{section.SectionKey}' display order must be 0 or more.");
            foreach (var action in section.Actions)
            {
                if (!ActionTypes.Contains(action.ActionType, StringComparer.OrdinalIgnoreCase))
                    throw new InvalidDomainValueException(
                        $"Action type '{action.ActionType}' is invalid (Show, Hide, Disable, Enable, Require, MakeOptional).");
                if (action.SortOrder < 0)
                    throw new InvalidDomainValueException($"Action '{action.ActionType}' sort order must be 0 or more.");
            }
        }
    }
}
