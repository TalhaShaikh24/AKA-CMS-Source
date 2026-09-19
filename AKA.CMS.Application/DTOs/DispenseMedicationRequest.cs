namespace AKA.CMS.Application.DTOs;

public sealed record DispenseMedicationRequest(
    DateTime DispensedDate,
    decimal Quantity,
    int? DispensedByUserId,
    string? AdherenceNotes);
