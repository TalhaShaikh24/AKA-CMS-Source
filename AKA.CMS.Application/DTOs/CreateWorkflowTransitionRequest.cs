namespace AKA.CMS.Application.DTOs;

public sealed record CreateWorkflowTransitionRequest(
    string FromState,
    string ActionCode,
    string ActionName,
    string ToState,
    string? RequiredPermissionName,
    int SortOrder);
