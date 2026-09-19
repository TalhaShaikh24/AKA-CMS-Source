namespace AKA.CMS.Domain.Entities;

public sealed class MedicationDispense
{
    public int DispenseId { get; set; }
    public int PrescriptionId { get; set; }
    public DateTime DispensedDate { get; set; }
    public decimal Quantity { get; set; }
    public int? DispensedByUserId { get; set; }
    public string? AdherenceNotes { get; set; }
    public byte[] RowVersion { get; set; } = [];
    public DateTime CreatedAt { get; set; }
}
