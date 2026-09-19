using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IHealthRepository
{
    /// <summary>Runs the trivial DB liveness ping. Returns UTC time from SQL Server.</summary>
    Task<DateTime> CheckDatabaseAsync();
}
