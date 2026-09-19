namespace AKA.CMS.Application.DTOs;

public sealed record SetTransitionActiveRequest(
    bool IsActive,
    byte[] RowVersion);
