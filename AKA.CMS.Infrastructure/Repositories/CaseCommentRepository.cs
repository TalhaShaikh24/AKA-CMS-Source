using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class CaseCommentRepository(DapperContext context) : ICaseCommentRepository
{
    public async Task<int> AddAsync(
        int caseId, string? commentType, string comment,
        int createdBy, string ipAddress)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@CommentType", commentType);
        parameters.Add("@Comment", comment);
        parameters.Add("@CreatedBy", createdBy);
        parameters.Add("@IpAddress", ipAddress);
        parameters.Add("@NewCommentId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.CaseCommentAdd, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewCommentId");
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
        catch (SqlException ex) when (ex.Number == 50010)
        {
            throw new InvalidDomainValueException(ex.Message);
        }
    }

    public async Task<IReadOnlyList<CaseComment>> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        try
        {
            var comments = await connection.QueryAsync<CaseComment>(
                StoredProcedures.CaseCommentGetByCase,
                new { CaseId = caseId }, commandType: CommandType.StoredProcedure);
            return comments.ToList();
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }
}
