namespace AKA.CMS.Application.DTOs;

public sealed record WorkloadEntryDto(
    int? AssignedToUserId,
    string? Username,
    int OpenCaseCount);

public sealed record WorkloadDto(IReadOnlyList<WorkloadEntryDto> Entries);
