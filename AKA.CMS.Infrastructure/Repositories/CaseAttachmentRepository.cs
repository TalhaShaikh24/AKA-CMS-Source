using System.Data;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class CaseAttachmentRepository(DapperContext context) : ICaseAttachmentRepository
{
    public async Task<int> UploadMetadataAsync(
        int caseId, string fileName, string contentType,
        long fileSizeBytes, string storagePath, int uploadedBy)
    {
        using var connection = context.CreateConnection();
        var parameters = new DynamicParameters();
        parameters.Add("@CaseId", caseId);
        parameters.Add("@FileName", fileName);
        parameters.Add("@ContentType", contentType);
        parameters.Add("@FileSizeBytes", fileSizeBytes);
        parameters.Add("@StoragePath", storagePath);
        parameters.Add("@UploadedBy", uploadedBy);
        parameters.Add("@NewAttachmentId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        try
        {
            await connection.ExecuteAsync(
                StoredProcedures.CaseAttachmentUpload, parameters,
                commandType: CommandType.StoredProcedure);
            return parameters.Get<int>("@NewAttachmentId");
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

    public async Task<IReadOnlyList<CaseAttachment>> GetByCaseAsync(int caseId)
    {
        using var connection = context.CreateConnection();
        try
        {
            var attachments = await connection.QueryAsync<CaseAttachment>(
                StoredProcedures.CaseAttachmentGetByCase,
                new { CaseId = caseId },
                commandType: CommandType.StoredProcedure);
            return attachments.ToList();
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }

    public async Task<CaseAttachment> GetByIdAsync(int attachmentId)
    {
        using var connection = context.CreateConnection();
        try
        {
            var attachment = await connection.QuerySingleOrDefaultAsync<CaseAttachment>(
                StoredProcedures.CaseAttachmentGetById,
                new { AttachmentId = attachmentId },
                commandType: CommandType.StoredProcedure);
            return attachment ?? throw new NotFoundException($"Attachment {attachmentId} not found.");
        }
        catch (SqlException ex) when (ex.Number == 50008)
        {
            throw new NotFoundException(ex.Message);
        }
    }

    public async Task<string?> GetSettingAsync(string settingKey)
    {
        using var connection = context.CreateConnection();
        var row = await connection.QuerySingleOrDefaultAsync<SettingRow>(
            StoredProcedures.SystemSettingGet,
            new { SettingKey = settingKey },
            commandType: CommandType.StoredProcedure);
        return row?.Value;
    }

    private sealed record SettingRow(string Key, string? Value);
}
