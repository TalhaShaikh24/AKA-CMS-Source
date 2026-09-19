namespace AKA.CMS.Application.DTOs;

public sealed record HealthCheckResponse(
    string Status,
    string Database,
    DateTime CheckedAtUtc,
    DateTime DatabaseUtcTime);
