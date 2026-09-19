namespace AKA.CMS.Application.DTOs;

public sealed record FacilityMrBlockDto(
    int FacilityMrBlockId,
    int UnitCode,
    string MrPrefix,
    int BlockStart,
    int BlockEnd,
    int NextSequence,
    bool IsPlaceholder,
    bool IsActive);
