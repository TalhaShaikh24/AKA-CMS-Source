namespace AKA.CMS.Domain.Entities;

public sealed class TreatmentPlan
{
    public int PlanId { get; set; }
    public int CaseId { get; set; }
    public string PlanTrack { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? Goals { get; set; }
    public string? PlannedInterventions { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime? PlannedEndDate { get; set; }
    public string Status { get; set; } = string.Empty;
    public byte[] RowVersion { get; set; } = [];
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public int PsychSessionCount { get; set; }
    public int PrescriptionCount { get; set; }
}
