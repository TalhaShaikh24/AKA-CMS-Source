using System.Data;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;
using Microsoft.Data.SqlClient;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class ScreeningToolRepository : IScreeningToolRepository
{
    private readonly DapperContext _context;

    public ScreeningToolRepository(DapperContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<ScreeningToolActiveDto>> GetActiveAsync()
    {
        using var connection = _context.CreateConnection();
        var rows = await connection.QueryAsync<ScreeningToolActiveDto>(
            StoredProcedures.ScreeningToolGetActive, commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    public async Task<IReadOnlyList<ScreeningToolDefDto>> GetAllAsync()
    {
        using var connection = _context.CreateConnection();
        var rows = await connection.QueryAsync<ScreeningToolDefDto>(
            StoredProcedures.ScreeningToolGetAllAdmin, commandType: CommandType.StoredProcedure);
        return rows.ToList();
    }

    public async Task<ScreeningToolDefDto?> GetByIdAsync(string toolCode)
    {
        using var connection = _context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@ToolCode", toolCode);
        return await connection.QuerySingleOrDefaultAsync<ScreeningToolDefDto>(
            StoredProcedures.ScreeningToolGetDetail, p, commandType: CommandType.StoredProcedure);
    }

    public async Task CreateAsync(CreateScreeningToolRequest request, string? questionsJson, int performedBy)
    {
        using var connection = _context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@ToolCode", request.ToolCode);
        p.Add("@ToolName", request.ToolName);
        p.Add("@Description", request.Description);
        p.Add("@ItemCount", request.ItemCount);
        p.Add("@MaxItemScore", request.MaxItemScore);
        p.Add("@SortOrder", request.SortOrder);
        p.Add("@QuestionsJson", questionsJson);
        p.Add("@PerformedBy", performedBy);
        try
        {
            await connection.ExecuteAsync(StoredProcedures.ScreeningToolCreateFull, p, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number == 50009)
        {
            throw new ScreeningValidationException(ex.Message);
        }
    }

    public async Task UpdateAsync(string toolCode, UpdateScreeningToolRequest request, string? questionsJson, int performedBy)
    {
        using var connection = _context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@ToolCode", toolCode);
        p.Add("@ToolName", request.ToolName);
        p.Add("@Description", request.Description);
        p.Add("@IsActive", request.IsActive);
        p.Add("@SortOrder", request.SortOrder);
        p.Add("@QuestionsJson", questionsJson);
        p.Add("@PerformedBy", performedBy);
        try
        {
            await connection.ExecuteAsync(StoredProcedures.ScreeningToolUpdateFull, p, commandType: CommandType.StoredProcedure);
        }
        catch (SqlException ex) when (ex.Number is 50008 or 50009)
        {
            if (ex.Number == 50008) throw new NotFoundException(ex.Message);
            throw new ScreeningValidationException(ex.Message);
        }
    }
}
