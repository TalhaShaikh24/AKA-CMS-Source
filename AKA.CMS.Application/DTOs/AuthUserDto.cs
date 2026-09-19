
namespace AKA.CMS.Application.DTOs;

public sealed record AuthUserDto(int UserId, string Username, IReadOnlyList<string> Roles);
