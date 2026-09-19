using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;

namespace AKA.CMS.Application.Services;

public sealed class HealthService(IHealthRepository healthRepository) : IHealthService
{
    public async Task<HealthCheckResponse> CheckAsync()
    {
        // A successful proc round-trip means the database is reachable.
        var dbUtcTime = await healthRepository.CheckDatabaseAsync();
        return new HealthCheckResponse("Healthy", "Reachable", DateTime.UtcNow, dbUtcTime);
    }
}
