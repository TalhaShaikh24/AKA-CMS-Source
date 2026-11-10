using System.Text.Json.Serialization;

namespace AKA.CMS.Application.DTOs;

/// <summary>One step of a workflow (DZ_ChildCareV3 tbl_WorkFlowSteps).
/// ResponsibleRoleID is who owns the step; in practice the next role
/// usually comes from the button that moves the instance (see
/// WorkflowStepActionDto), exactly like the old system.</summary>
public sealed class WorkflowStepDto
{
    public int WorkflowStepId { get; set; }
    public int WorkflowId { get; set; }
    public string StepCode { get; set; } = string.Empty;
    public string StepTitle { get; set; } = string.Empty;
    public int? ResponsibleRoleID { get; set; }
    public string? ResponsibleRoleName { get; set; }
    public int? ResponsibleWorkflowRoleID { get; set; }
    public string? ResponsibleWorkflowRoleName { get; set; }
    public bool IsStart { get; set; }
    public bool IsEnd { get; set; }
    public int? SLA { get; set; }
    public int DisplayOrder { get; set; }
    public bool IsActive { get; set; }
    public int StepActionCount { get; set; }
    public int StepSectionCount { get; set; }
}

public sealed class SaveWorkflowStepRequest
{
    public string StepCode { get; set; } = string.Empty;
    public string StepTitle { get; set; } = string.Empty;
    public int? ResponsibleRoleID { get; set; }
    public int? ResponsibleWorkflowRoleID { get; set; }
    public bool IsStart { get; set; }
    public bool IsEnd { get; set; }
    public int? SLA { get; set; }
    public int DisplayOrder { get; set; }
}

/// <summary>One per-step section permission (old
/// tbl_Workflow_StepSectionPermission): at this step, does this
/// section show, and can its fields be edited.</summary>
public sealed class WorkflowStepSectionDto
{
    public int WorkflowStepSectionId { get; set; }
    public int WorkflowStepId { get; set; }
    public string SectionKey { get; set; } = string.Empty;
    public bool IsVisible { get; set; }
    public bool IsEnable { get; set; }
    public int DisplayOrder { get; set; }
}

public sealed class SaveWorkflowStepSectionRequest
{
    public string SectionKey { get; set; } = string.Empty;
    public bool IsVisible { get; set; } = true;
    public bool IsEnable { get; set; } = true;
    public int DisplayOrder { get; set; }
}

/// <summary>One button under the form at a step (old
/// tbl_WorkFlowStep_Actions). This is NOT a field action
/// (WorkflowActionDto): a button moves the whole request to the
/// next step and hands it to the next role. It changes no field.</summary>
public sealed class WorkflowStepActionDto
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

public sealed class SaveWorkflowStepActionRequest
{
    public string ActionCode { get; set; } = string.Empty;
    public string ActionTitle { get; set; } = string.Empty;
    public string NextStepCode { get; set; } = string.Empty;
    public string NextAssignmentType { get; set; } = "Static";
    public int? NextRoleID { get; set; }
    public int? NextWorkflowRoleID { get; set; }
    public bool SaveOrMove { get; set; } = true;
    public bool IsSendEmail { get; set; }
    public int DisplayOrder { get; set; }
}

/// <summary>One live request travelling a workflow (old
/// tbl_WorkFlow_Instance): where it is right now, who has to act,
/// and its SLA. Stage is carried, never interpreted — the old data
/// never wrote down what its numbers mean.</summary>
public sealed class WorkflowInstanceDto
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
    // STJ camelCases "SLA_Date" to "slA_Date"; the JS reads "sla_Date".
    // Pin the wire name so the My Tasks SLA column is not blank.
    [JsonPropertyName("sla_NoOfDays")]
    public int? SLA_NoOfDays { get; set; }
    [JsonPropertyName("sla_Date")]
    public DateTime? SLA_Date { get; set; }
    public int? Stage { get; set; }
    public string? Comments { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public sealed class StartWorkflowInstanceRequest
{
    public int WorkflowId { get; set; }
    public int SubmissionId { get; set; }
    public string? Comments { get; set; }
}

public sealed class ExecuteWorkflowActionRequest
{
    public string? Comments { get; set; }
}

/// <summary>One move of an instance (old tbl_WorkFlow_Instance_Log):
/// the history row written on every start and every button press.</summary>
public sealed class WorkflowInstanceLogDto
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
    // STJ camelCases "SLA_Date" to "slA_Date"; the JS reads "sla_Date".
    // Pin the wire name so the My Tasks SLA column is not blank.
    [JsonPropertyName("sla_NoOfDays")]
    public int? SLA_NoOfDays { get; set; }
    [JsonPropertyName("sla_Date")]
    public DateTime? SLA_Date { get; set; }
    public int? Stage { get; set; }
    public string? Comments { get; set; }
    public DateTime LogDate { get; set; }
    public string? Status { get; set; }
}

/// <summary>The buttons under the form at an instance's current step,
/// with the step they belong to.</summary>
public sealed class WorkflowStepActionsResponseDto
{
    public int WorkflowStepId { get; set; }
    public string StepCode { get; set; } = string.Empty;
    public string StepTitle { get; set; } = string.Empty;
    public bool IsStart { get; set; }
    public bool IsEnd { get; set; }
    public List<WorkflowStepActionDto> Actions { get; set; } = new();
}
