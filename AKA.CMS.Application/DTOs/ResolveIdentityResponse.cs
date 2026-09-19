namespace AKA.CMS.Application.DTOs;

public sealed record ResolveIdentityResponse(
    int MappingId,
    string MrNo,
    bool IsDummy,
    bool WasCreated,
    int UnitCode,
    string? ResolvedMrNo,
    byte[] RowVersion);
