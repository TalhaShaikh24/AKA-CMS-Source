namespace AKA.CMS.Domain.Entities;

public sealed class CaseSourceMapping
{
    public int MappingId { get; set; }
    public int CaseId { get; set; }
    public string SourceType { get; set; } = string.Empty;
    public string? SourceDisplayName { get; set; }
    public int? SourceReferenceId { get; set; }
    public DateTime CreatedAt { get; set; }
}
