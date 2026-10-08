using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class TaskRepository(DapperContext context) : ITaskRepository
{
    public async Task<IReadOnlyList<TaskItem>> GetAllAsync(string tab, int? caseId, int? assignedToUserId)
    {
        using var connection = context.CreateConnection();
        var tasks = await connection.QueryAsync<TaskItem>(
            StoredProcedures.TaskGetAll,
            new { Tab = tab, CaseId = caseId, AssignedToUserId = assignedToUserId },
            commandType: CommandType.StoredProcedure);
        return tasks.ToList();
    }

    public async Task<TaskItem?> GetByIdAsync(int taskId)
    {
        using var connection = context.CreateConnection();
        return await connection.QuerySingleOrDefaultAsync<TaskItem>(
            StoredProcedures.TaskGetById,
            new { TaskId = taskId },
            commandType: CommandType.StoredProcedure);
    }

    public async Task<int> CreateAsync(TaskItem task, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@Title", task.Title);
        parameters.Add("@Description", task.Description);
        parameters.Add("@CaseId", task.CaseId);
        parameters.Add("@TaskType", task.TaskType);
        parameters.Add("@Priority", task.Priority);
        parameters.Add("@DueDate", task.DueDate.Date);
        parameters.Add("@AssignedToRoleId", task.AssignedToRoleId);
        parameters.Add("@AssignedToUserId", task.AssignedToUserId);
        parameters.Add("@NotifyRecipients", task.NotifyRecipients);
        parameters.Add("@CreatedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewTaskId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.TaskCreate, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewTaskId");
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }

    public async Task UpdateStatusAsync(
        int taskId, string status, byte[] rowVersion, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@TaskId", taskId);
        parameters.Add("@Status", status);
        parameters.Add("@RowVersion", rowVersion, DbType.Binary);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.TaskUpdateStatus, parameters,
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException($"Task {taskId} not found.");
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException(ex.Message);
        }
    }

    public async Task AssignAsync(
        int taskId, int? roleId, int? userId, byte[] rowVersion, int performedBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@TaskId", taskId);
        parameters.Add("@AssignedToRoleId", roleId);
        parameters.Add("@AssignedToUserId", userId);
        parameters.Add("@RowVersion", rowVersion, DbType.Binary);
        parameters.Add("@PerformedBy", performedBy);
        parameters.Add("@IpAddress", ipAddress);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.TaskAssign, parameters,
                commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50005)
        {
            throw new ConcurrencyException(ex.Message);
        }
    }
}
