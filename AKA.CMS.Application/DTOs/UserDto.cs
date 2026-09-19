
namespace AKA.CMS.Application.DTOs;

public sealed record UserDto(
    int UserId,
    string Username,
    bool IsActive,
    bool IsLocked,
    bool IsAdmin,
    IReadOnlyList<string> Roles);
