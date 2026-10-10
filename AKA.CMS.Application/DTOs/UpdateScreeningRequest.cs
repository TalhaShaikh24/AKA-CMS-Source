namespace AKA.CMS.Application.DTOs;

public sealed record UpdateScreeningRequest(
    IReadOnlyList<int> ItemScores,
    byte[] RowVersion);
