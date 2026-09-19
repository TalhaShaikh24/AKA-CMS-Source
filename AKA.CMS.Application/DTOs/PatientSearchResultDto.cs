namespace AKA.CMS.Application.DTOs;

public sealed record PatientSearchResultDto(
    string Source,
    int? MemberId,
    string? MrNo,
    string? FullName,
    string? Gender,
    string? Phone,
    int? UnitCode,
    DateTime? LastEncounterAt);
