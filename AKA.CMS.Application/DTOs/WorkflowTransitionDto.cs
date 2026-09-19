namespace AKA.CMS.Application.DTOs;

public sealed record WorkflowTransitionDto(
    int TransitionId,
    string FromState,
    string ActionCode,
    string ActionName,
    string ToState,
    string RequiredPermissionName,
    int SortOrder,
    bool IsActive,
    byte[] RowVersion);
