namespace AKA.CMS.Domain.Entities;

public sealed class AwarenessSession
{
    public int SessionId { get; set; }
    public string SessionCode { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? FacilityCode { get; set; }
    public DateTime SessionDate { get; set; }
    public int? ConductedBy { get; set; }
    public string? Topic { get; set; }
    public string? TargetGroup { get; set; }
    public string? Venue { get; set; }
    public int MaleCount { get; set; }
    public int FemaleCount { get; set; }
    public int OtherCount { get; set; }
    public string? Notes { get; set; }
    public byte[] RowVersion { get; set; } = [];
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public int ParticipantCount { get; set; }
}
