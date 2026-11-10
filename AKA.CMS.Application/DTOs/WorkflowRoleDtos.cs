namespace AKA.CMS.Application.DTOs;

/// <summary>A workflow role: who a workflow step is waiting on.
/// Separate from a user role (ROLES) — a user role says what a user
/// may do in the app; a workflow role says who must act next.
/// Assigning one to a user is optional.</summary>
public sealed class WorkflowRoleDto
{
    public int WorkflowRoleId { get; set; }
    public string WorkflowRoleCode { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsActive { get; set; }
    public int UserCount { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
}

public sealed class SaveWorkflowRoleRequest
{
    public string WorkflowRoleCode { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
}

/// <summary>One user holding a workflow role.</summary>
public sealed class WorkflowRoleUserDto
{
    public int UserWorkflowRoleId { get; set; }
    public int UserId { get; set; }
    public string Username { get; set; } = string.Empty;
    public string? Email { get; set; }
    public DateTime CreatedAt { get; set; }
}

public sealed class SaveWorkflowRoleUsersRequest
{
    public List<int> UserIds { get; set; } = new();
}

/// <summary>A workflow role held by one user (their own list).</summary>
public sealed class UserWorkflowRoleDto
{
    public int WorkflowRoleId { get; set; }
    public string WorkflowRoleCode { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
}
