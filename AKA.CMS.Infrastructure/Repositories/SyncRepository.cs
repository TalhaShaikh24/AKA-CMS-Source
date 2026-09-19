using System.Data;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class SyncRepository(DapperContext context) : ISyncRepository
{
    public async Task<SyncPushResponse> PushAsync(
        string idempotencyKey, string deviceId, string entityType,
        int? entityId, string action, string payloadJson,
        DateTime? baseVersion, int performedBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@IdempotencyKey", idempotencyKey);
        parameters.Add("@DeviceId", deviceId);
        parameters.Add("@EntityType", entityType);
        parameters.Add("@EntityId", entityId);
        parameters.Add("@Action", action);
        parameters.Add("@PayloadJson", payloadJson);
        parameters.Add("@BaseVersion", baseVersion);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@OutboxId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        parameters.Add("@Status", dbType: DbType.String, size: 20, direction: ParameterDirection.Output);
        parameters.Add("@IsDuplicate", dbType: DbType.Boolean, direction: ParameterDirection.Output);
        parameters.Add("@ConflictReport", dbType: DbType.String, size: -1, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.SyncOutboxPush, parameters,
                commandType: CommandType.StoredProcedure);
            return new SyncPushResponse(
                parameters.Get<int>("@OutboxId"),
                parameters.Get<string>("@Status") ?? string.Empty,
                parameters.Get<bool>("@IsDuplicate"),
                parameters.Get<string?>("@ConflictReport"));
        }
        catch (SqlException ex) when (ex.Number == 50009)
        {
            throw new ScreeningValidationException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50010)
        {
            throw new InvalidDomainValueException(ex.Message);
        }
    }

    public async Task<(IReadOnlyList<SyncPullItemDto> Items, long TotalCount)> PullAsync(
        DateTime since, int page, int pageSize)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@Since", since);
        parameters.Add("@Page", page);
        parameters.Add("@PageSize", pageSize);
        parameters.Add("@TotalCount", dbType: DbType.Int64, direction: ParameterDirection.Output);
        try
        {
            var items = await connection.QueryAsync<SyncPullItemDto>(
                StoredProcedures.SyncPull, parameters,
                commandType: CommandType.StoredProcedure);
            return (items.ToList(), parameters.Get<long>("@TotalCount"));
        }
        catch (SqlException ex) when (ex.Number == 50009)
        {
            throw new ScreeningValidationException(ex.Message);
        }
    }

    public async Task AcknowledgeAsync(string idempotencyKey, string deviceId, int performedBy)
    {
        using var connection = context.CreateConnection();
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.SyncOutboxAck,
                new { IdempotencyKey = idempotencyKey, DeviceId = deviceId, PerformedBy = performedBy },
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }
}
