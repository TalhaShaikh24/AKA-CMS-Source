namespace AKA.CMS.Application.DTOs;

public sealed record CreateUserRequest(
    string Username,
    string Password,
    string? Email,
    IReadOnlyList<int>? RoleIds);
