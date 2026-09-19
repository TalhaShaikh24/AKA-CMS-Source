namespace AKA.CMS.Domain.Entities;

public sealed class PsychologicalSession
{
    public int SessionId { get; set; }
    public int PlanId { get; set; }
    public int CaseId { get; set; }
    public int? TherapistUserId { get; set; }
    public DateTime SessionDate { get; set; }
    public string ModalityCode { get; set; } = string.Empty;
    public string? ModalityName { get; set; }
    public int? DurationMinutes { get; set; }
    public string? SessionNotes { get; set; }
    public string? OutcomeNotes { get; set; }
    public DateTime? NextSessionDate { get; set; }
    public byte[] RowVersion { get; set; } = [];
    public DateTime CreatedAt { get; set; }
}
