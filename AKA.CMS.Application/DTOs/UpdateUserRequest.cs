namespace AKA.CMS.Application.DTOs;

public sealed record UpdateUserRequest(
    bool? IsActive,
    bool? IsLocked,
    string? NewPassword,
    string? Email);
