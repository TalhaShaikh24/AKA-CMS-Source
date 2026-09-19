namespace AKA.CMS.Application.DTOs;

public sealed record UpdateCaseRequest(
    string? PriorityLevel,
    string? Notes,
    byte[] RowVersion);
