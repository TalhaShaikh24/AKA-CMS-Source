namespace AKA.CMS.Domain.Entities;

public sealed class PatientSearchHit
{
    public string Source { get; set; } = string.Empty;
    public int? MemberId { get; set; }
    public string? MrNo { get; set; }
    public string? FullName { get; set; }
    public string? Gender { get; set; }
    public string? Phone { get; set; }
    public int? UnitCode { get; set; }
    public DateTime? LastEncounterAt { get; set; }
}
