using System.Data;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class NotificationRepository(DapperContext context) : INotificationRepository
{
    public async Task<int> CreateAsync(
        string? recipientRole, int? recipientUserId, string title, string body,
        int? relatedCaseId, string? relatedEntity, int? relatedEntityId,
        string? pushPayload, int createdBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@RecipientRole", recipientRole);
        parameters.Add("@RecipientUserId", recipientUserId);
        parameters.Add("@Title", title);
        parameters.Add("@Body", body);
        parameters.Add("@RelatedCaseId", relatedCaseId);
        parameters.Add("@RelatedEntity", relatedEntity);
        parameters.Add("@RelatedEntityId", relatedEntityId);
        parameters.Add("@PushPayload", pushPayload);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@NewNotificationId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.NotificationCreate, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewNotificationId");
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50009)
        {
            throw new ScreeningValidationException(ex.Message);
        }
    }

    public async Task<(IReadOnlyList<Notification> Items, int TotalCount)> GetByUserAsync(
        int userId, bool unreadOnly, int page, int pageSize)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@UserId", userId);
        parameters.Add("@UnreadOnly", unreadOnly);
        parameters.Add("@Page", page);
        parameters.Add("@PageSize", pageSize);
        parameters.Add("@TotalCount", dbType: DbType.Int32, direction: ParameterDirection.Output);
        var items = await connection.QueryAsync<Notification>(
            StoredProcedures.NotificationGetByUser, parameters,
            commandType: CommandType.StoredProcedure);
        return (items.ToList(), parameters.Get<int>("@TotalCount"));
    }

    public async Task MarkAsReadAsync(int notificationId, int userId)
    {
        using var connection = context.CreateConnection();
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.NotificationMarkAsRead,
                new { NotificationId = notificationId, UserId = userId },
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }

    public async Task<int> MarkAllReadAsync(int userId)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@UserId", userId);
        parameters.Add("@MarkedCount", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await connection.ExecuteAsync(
            StoredProcedures.NotificationMarkAllRead, parameters,
            commandType: CommandType.StoredProcedure);
        return parameters.Get<int>("@MarkedCount");
    }
}
