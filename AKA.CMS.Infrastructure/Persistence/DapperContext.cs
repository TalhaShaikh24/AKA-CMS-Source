using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace AKA.CMS.Infrastructure.Persistence;

public sealed class DapperContext(IConfiguration configuration)
{
    private readonly string _connectionString =
        configuration.GetConnectionString("DefaultConnection")
        ?? throw new InvalidOperationException("Connection string 'DefaultConnection' is missing.");

    public IDbConnection CreateConnection() => new SqlConnection(_connectionString);
}
