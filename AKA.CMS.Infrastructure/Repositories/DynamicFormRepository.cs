using System.Data;
using System.Text.Json;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Infrastructure.Persistence;
using Dapper;

namespace AKA.CMS.Infrastructure.Repositories;

public sealed class DynamicFormRepository(DapperContext context) : IDynamicFormRepository
{
    private sealed class FormRow
    {
        public int FormId { get; set; }
        public string FormKey { get; set; } = string.Empty;
        public string Title { get; set; } = string.Empty;
        public string? Description { get; set; }
        public bool IsActive { get; set; }
        public int FieldCount { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }

    private sealed class FieldRow
    {
        public int FieldId { get; set; }
        public string FieldKey { get; set; } = string.Empty;
        public string Label { get; set; } = string.Empty;
        public string FieldType { get; set; } = "text";
        public string? Placeholder { get; set; }
        public string? HelpText { get; set; }
        public bool IsRequired { get; set; }
        public string? DefaultValue { get; set; }
        public string? OptionsJson { get; set; }
        public int? MinLength { get; set; }
        public int? MaxLength { get; set; }
        public decimal? MinValue { get; set; }
        public decimal? MaxValue { get; set; }
        public string? Accept { get; set; }
        public int ColumnSpan { get; set; }
        public int SortOrder { get; set; }
    }

    public async Task<IReadOnlyList<DynamicFormListItemDto>> GetAllAsync()
    {
        using var connection = context.CreateConnection();
        var rows = await connection.QueryAsync<FormRow>(
            StoredProcedures.DynamicFormGetAll, commandType: CommandType.StoredProcedure);
        return rows.Select(r => new DynamicFormListItemDto
        {
            FormId = r.FormId, FormKey = r.FormKey, Title = r.Title, Description = r.Description,
            IsActive = r.IsActive, FieldCount = r.FieldCount, CreatedAt = r.CreatedAt, UpdatedAt = r.UpdatedAt
        }).ToList();
    }

    public async Task<DynamicFormDetailDto?> GetByIdAsync(int formId)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@FormId", formId);
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.DynamicFormGetById, p, commandType: CommandType.StoredProcedure);
        var form = await multi.ReadSingleOrDefaultAsync<FormRow>();
        if (form is null) return null;
        var fields = (await multi.ReadAsync<FieldRow>()).ToList();
        return new DynamicFormDetailDto
        {
            FormId = form.FormId, FormKey = form.FormKey, Title = form.Title,
            Description = form.Description, IsActive = form.IsActive,
            FieldCount = form.FieldCount, CreatedAt = form.CreatedAt, UpdatedAt = form.UpdatedAt,
            Fields = fields.Select(f => new DynamicFormFieldDto
            {
                FieldId = f.FieldId, FieldKey = f.FieldKey, Label = f.Label, FieldType = f.FieldType,
                Placeholder = f.Placeholder, HelpText = f.HelpText, IsRequired = f.IsRequired,
                DefaultValue = f.DefaultValue,
                Options = ParseOptions(f.OptionsJson),
                MinLength = f.MinLength, MaxLength = f.MaxLength,
                MinValue = f.MinValue, MaxValue = f.MaxValue,
                Accept = f.Accept, ColumnSpan = f.ColumnSpan, SortOrder = f.SortOrder
            }).ToList()
        };
    }

    public async Task<int> SaveAsync(int formId, SaveDynamicFormRequest request, int performedBy)
    {
        var fieldPayload = request.Fields.Select((f, i) => new
        {
            fieldKey = f.FieldKey.Trim(),
            label = f.Label,
            fieldType = f.FieldType,
            placeholder = f.Placeholder,
            helpText = f.HelpText,
            isRequired = f.IsRequired,
            defaultValue = f.DefaultValue,
            // Real JSON array (not a serialized string) — the SP reads it AS JSON.
            optionsJson = DynamicFormFieldTypes.HasOptions(f.FieldType)
                ? f.Options.Select(o => new { value = o.Value, label = o.Label }).ToList()
                : null,
            minLength = f.MinLength,
            maxLength = f.MaxLength,
            minValue = f.MinValue,
            maxValue = f.MaxValue,
            accept = f.Accept,
            columnSpan = f.ColumnSpan,
            sortOrder = i
        });

        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@FormId", formId);
        p.Add("@FormKey", request.FormKey.Trim());
        p.Add("@Title", request.Title.Trim());
        p.Add("@Description", request.Description);
        p.Add("@IsActive", request.IsActive);
        p.Add("@FieldsJson", JsonSerializer.Serialize(fieldPayload));
        p.Add("@PerformedBy", performedBy);
        p.Add("@NewFormId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await connection.ExecuteAsync(
            StoredProcedures.DynamicFormSave, p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("@NewFormId");
    }

    public async Task DeleteAsync(int formId, int performedBy)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@FormId", formId);
        p.Add("@PerformedBy", performedBy);
        await connection.ExecuteAsync(
            StoredProcedures.DynamicFormDelete, p, commandType: CommandType.StoredProcedure);
    }

    private static List<DynamicFormFieldOptionDto> ParseOptions(string? optionsJson)
    {
        if (string.IsNullOrWhiteSpace(optionsJson)) return new();
        try
        {
            return JsonSerializer.Deserialize<List<DynamicFormFieldOptionDto>>(optionsJson,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new();
        }
        catch (JsonException)
        {
            return new();
        }
    }
}
