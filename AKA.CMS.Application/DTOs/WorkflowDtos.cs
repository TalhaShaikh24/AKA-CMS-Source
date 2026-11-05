namespace AKA.CMS.Application.DTOs;

/// <summary>One action the workflow performs when the form loads.
/// ActionType is one of Show, Hide, Disable, Enable, Require,
/// MakeOptional. TargetKey is a field key when the action is on a
/// single field inside the section; null means the whole section.</summary>
public sealed class WorkflowActionDto
{
    public int WorkflowActionId { get; set; }
    public string SectionKey { get; set; } = string.Empty;
    public string ActionType { get; set; } = string.Empty;
    public string? TargetKey { get; set; }
    public int SortOrder { get; set; }
}

/// <summary>One section of the form as the workflow sees it:
/// whether it shows on load, in what order, and what to do with it.
/// SectionKey is the section's FieldKey in CMS_DynamicFormFields.</summary>
public sealed class WorkflowSectionDto
{
    public string SectionKey { get; set; } = string.Empty;
    public bool IsVisible { get; set; }
    public int DisplayOrder { get; set; }
    public List<WorkflowActionDto> Actions { get; set; } = new();
}

public sealed class WorkflowDetailDto
{
    public int WorkflowId { get; set; }
    public string WorkflowName { get; set; } = string.Empty;
    public int FormId { get; set; }
    public string FormKey { get; set; } = string.Empty;
    public string FormTitle { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsActive { get; set; }
    public List<WorkflowSectionDto> Sections { get; set; } = new();
}

public sealed class WorkflowListItemDto
{
    public int WorkflowId { get; set; }
    public string WorkflowName { get; set; } = string.Empty;
    public int FormId { get; set; }
    public string FormKey { get; set; } = string.Empty;
    public string FormTitle { get; set; } = string.Empty;
    public bool IsActive { get; set; }
    public int SectionCount { get; set; }
}

/// <summary>What Get Workflow Sections returns for a form: the active
/// workflow's sections in display order, each with its actions.
/// Empty sections = no active workflow = the form shows everything.</summary>
public sealed class WorkflowSectionsResponseDto
{
    public int? WorkflowId { get; set; }
    public List<WorkflowSectionDto> Sections { get; set; } = new();
}

public sealed class SaveWorkflowActionRequest
{
    public string ActionType { get; set; } = string.Empty;
    public string? TargetKey { get; set; }
    public int SortOrder { get; set; }
}

public sealed class SaveWorkflowSectionRequest
{
    public string SectionKey { get; set; } = string.Empty;
    public bool IsVisible { get; set; } = true;
    public int DisplayOrder { get; set; }
    public List<SaveWorkflowActionRequest> Actions { get; set; } = new();
}

/// <summary>Create or fully replace a workflow. Sections and actions
/// are replaced wholesale, like DynamicForm Save replaces fields.</summary>
public sealed class SaveWorkflowRequest
{
    public string WorkflowName { get; set; } = string.Empty;
    public int FormId { get; set; }
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
    public List<SaveWorkflowSectionRequest> Sections { get; set; } = new();
}
