namespace AKA.CMS.Domain.Entities;

public sealed class Medication
{
    public int MedicationId { get; set; }
    public string MedicationCode { get; set; } = string.Empty;
    public string GenericName { get; set; } = string.Empty;
    public string? Strength { get; set; }
    public string? DosageForm { get; set; }
    public bool ClinicalConfirmationPending { get; set; }
    public int SortOrder { get; set; }
}
