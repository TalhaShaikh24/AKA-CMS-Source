namespace AKA.CMS.Application.DTOs;

/// <summary>Create a user. For AD users (UserType = "AD") no local password is
/// set — they authenticate against Active Directory; Password is ignored.</summary>
public sealed record CreateUserRequest(
    string Username,
    string? Password,
    string? Email,
    IReadOnlyList<int>? RoleIds,
    string? UserType = "System");
