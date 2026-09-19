namespace AKA.CMS.Application.DTOs;

public sealed record AllowedTransitionDto(
    string ActionCode,
    string ActionName,
    string FromState,
    string ToState,
    string? ToStateName,
    string RequiredPermissionName,
    bool CanPerform);
