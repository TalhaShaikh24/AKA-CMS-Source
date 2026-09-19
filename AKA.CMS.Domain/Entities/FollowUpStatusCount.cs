namespace AKA.CMS.Domain.Entities;

public sealed class FollowUpStatusCount
{
    public string Status { get; set; } = string.Empty;
    public int FollowUpCount { get; set; }
}
