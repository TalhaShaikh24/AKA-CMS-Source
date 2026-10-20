namespace AKA.CMS.Application.DTOs;

/// <summary>Create a user. AD users also receive a local password for now —
/// until real AD (LDAP) login is connected, that is how they sign in.</summary>
public sealed record CreateUserRequest(
    string Username,
    string? Password,
    string? Email,
    IReadOnlyList<int>? RoleIds,
    string? UserType = "System");
