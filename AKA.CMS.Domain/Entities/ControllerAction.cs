namespace AKA.CMS.Domain.Entities;

public sealed class ControllerAction
{
    public int Id { get; set; }
    public string ControllerName { get; set; } = string.Empty;
    public string Action { get; set; } = string.Empty;

    public string PolicyName => $"Permissions:{ControllerName}:{Action}";
    public string ClaimValue => $"{ControllerName}:{Action}";
}
