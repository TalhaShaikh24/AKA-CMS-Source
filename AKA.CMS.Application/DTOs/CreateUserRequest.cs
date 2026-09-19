
namespace AKA.CMS.Application.DTOs;

public sealed record CreateUserRequest(
    string Username,
    string Password,
    IReadOnlyList<int>? RoleIds);
