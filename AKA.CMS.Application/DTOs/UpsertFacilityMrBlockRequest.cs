namespace AKA.CMS.Application.DTOs;

public sealed record UpsertFacilityMrBlockRequest(
    int UnitCode,
    string MrPrefix,
    int BlockStart,
    int BlockEnd,
    bool IsActive);
