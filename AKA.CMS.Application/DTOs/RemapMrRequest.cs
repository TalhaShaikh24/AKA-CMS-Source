namespace AKA.CMS.Application.DTOs;

public sealed record RemapMrRequest(
    int MappingId,
    string RealMrNo,
    byte[] RowVersion);
