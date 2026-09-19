namespace AKA.CMS.Application.DTOs;

public sealed record WorkflowStateDto(
    string StateCode,
    string StateName,
    string? Description,
    bool IsInitial,
    bool IsTerminal,
    int SortOrder);
