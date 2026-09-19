namespace AKA.CMS.Domain.Entities;

public sealed class WorkloadEntry
{
    public int? AssignedToUserId { get; set; }
    public string? Username { get; set; }
    public int OpenCaseCount { get; set; }
}
