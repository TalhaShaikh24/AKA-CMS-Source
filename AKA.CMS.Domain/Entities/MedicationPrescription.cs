namespace AKA.CMS.Domain.Entities;

public sealed class MedicationPrescription
{
    public int PrescriptionId { get; set; }
    public string RxNumber { get; set; } = string.Empty;
    public int CaseId { get; set; }
    public int? PlanId { get; set; }
    public int MedicationId { get; set; }
    public string MedicationCode { get; set; } = string.Empty;
    public string GenericName { get; set; } = string.Empty;
    public string? Strength { get; set; }
    public string? DosageForm { get; set; }
    public int? PrescribedByUserId { get; set; }
    public string DoseText { get; set; } = string.Empty;
    public string Frequency { get; set; } = string.Empty;
    public int DurationDays { get; set; }
    public string? Instructions { get; set; }
    public string? DiagnosisText { get; set; }
    public string Status { get; set; } = string.Empty;
    public byte[] RowVersion { get; set; } = [];
    public DateTime CreatedAt { get; set; }
    public int DispenseCount { get; set; }
}
