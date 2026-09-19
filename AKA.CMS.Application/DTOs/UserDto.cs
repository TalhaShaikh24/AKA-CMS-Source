namespace AKA.CMS.Application.DTOs;

public sealed record UserDto(
    int UserId,
    string Username,
    string? Email,
    bool IsActive,
    bool IsLocked,
    bool IsAdmin,
    IReadOnlyList<string> Roles);
