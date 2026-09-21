namespace AKA.CMS.Application.DTOs;

public sealed record CarerDto(
    int CarerId,
    int CaseId,
    string FullName,
    string? Relationship,
    string? Phone,
    bool IsPrimary,
    int CreatedBy,
    string? CreatedByUsername,
    DateTime CreatedAt,
    byte[] RowVersion);

public sealed record AddCarerRequest(
    int CaseId,
    string FullName,
    string? Relationship,
    string? Phone,
    bool IsPrimary);

public sealed record UpdateCarerRequest(
    string FullName,
    string? Relationship,
    string? Phone,
    bool IsPrimary,
    byte[] RowVersion);
