namespace AKA.CMS.Application.DTOs;

public sealed record UserDto(
    int UserId,
    string Username,
    string? Email,
    bool IsActive,
    bool IsLocked,
    bool IsAdmin,
    IReadOnlyList<string> Roles,
    string UserType = "System");

/// <summary>One entry from the (dummy, for now) Active Directory user list.</summary>
public sealed record AdDirectoryUserDto(
    int AdUserId,
    string Username,
    string DisplayName,
    string? Email,
    string? Department,
    string? JobTitle,
    bool AlreadyAdded);
