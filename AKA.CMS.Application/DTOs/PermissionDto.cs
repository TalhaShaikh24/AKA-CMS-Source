
namespace AKA.CMS.Application.DTOs;

public sealed record PermissionDto(int Id, string ControllerName, string Action, string PolicyName);
