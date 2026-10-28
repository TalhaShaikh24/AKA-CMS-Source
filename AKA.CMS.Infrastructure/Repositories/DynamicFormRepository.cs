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
        public bool IsMultiStep { get; set; }
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
        public string? ChoiceLayout { get; set; }
        public string? ButtonAction { get; set; }
        public string? RegexPattern { get; set; }
        public string? ValidationMessage { get; set; }
        public int? LookupFormId { get; set; }
        public string? LookupFieldKey { get; set; }
        public int? SectionColumns { get; set; }
        public int? ColumnIndex { get; set; }
        public string? CustomJs { get; set; }
        public string? CssClass { get; set; }
        public string? CustomId { get; set; }
        public string? CustomAttributesJson { get; set; }
        public string? ValidationRulesJson { get; set; }
        public string? InputMask { get; set; }
        public string? ParentKey { get; set; }
        public bool? ShowBorder { get; set; }
        public bool? ShowDivider { get; set; }
        public bool ShowInfoIcon { get; set; }
        public string? InfoText { get; set; }
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
            IsActive = r.IsActive, IsMultiStep = r.IsMultiStep, FieldCount = r.FieldCount, CreatedAt = r.CreatedAt, UpdatedAt = r.UpdatedAt
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
            Description = form.Description, IsActive = form.IsActive, IsMultiStep = form.IsMultiStep,
            FieldCount = form.FieldCount, CreatedAt = form.CreatedAt, UpdatedAt = form.UpdatedAt,
            Fields = ResolveParents(fields).Select(f => new DynamicFormFieldDto
            {
                FieldId = f.FieldId, FieldKey = f.FieldKey, Label = f.Label, FieldType = f.FieldType,
                Placeholder = f.Placeholder, HelpText = f.HelpText, IsRequired = f.IsRequired,
                DefaultValue = f.DefaultValue,
                Options = f.FieldType == "grid" ? new List<DynamicFormFieldOptionDto>() : ParseOptions(f.OptionsJson),
                GridColumns = f.FieldType == "grid" ? ParseGridColumns(f.OptionsJson) : new List<DynamicFormGridColumnDto>(),
                MinLength = f.MinLength, MaxLength = f.MaxLength,
                MinValue = f.MinValue, MaxValue = f.MaxValue,
                Accept = f.Accept, ChoiceLayout = f.ChoiceLayout,
                ButtonAction = f.ButtonAction, RegexPattern = f.RegexPattern,
                ValidationMessage = f.ValidationMessage,
                LookupFormId = f.LookupFormId, LookupFieldKey = f.LookupFieldKey,
                SectionColumns = f.SectionColumns, ColumnIndex = f.ColumnIndex,
                CustomJs = f.CustomJs, CssClass = f.CssClass, CustomId = f.CustomId,
                CustomAttributes = ParseCustomAttributes(f.CustomAttributesJson),
                ValidationRules = ParseValidationRules(f.ValidationRulesJson),
                InputMask = f.InputMask, ParentKey = f.ParentKey, ShowBorder = f.ShowBorder, ShowDivider = f.ShowDivider, ShowInfoIcon = f.ShowInfoIcon, InfoText = f.InfoText,
                ColumnSpan = f.ColumnSpan, SortOrder = f.SortOrder
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
            // Real JSON (not a serialized string) — the SP reads it AS JSON.
            // Option fields store [{value,label}]; grid fields store their
            // columns [{key,label,type,options}] in the same column.
            optionsJson = f.FieldType == "grid"
                ? (object)f.GridColumns.Select(c => new
                    {
                        key = c.Key, label = c.Label, type = c.Type,
                        options = c.Options.Select(o => new { value = o.Value, label = o.Label }).ToList()
                    }).ToList()
                : DynamicFormFieldTypes.HasOptions(f.FieldType)
                    ? f.Options.Select(o => new { value = o.Value, label = o.Label }).ToList()
                    : null,
            buttonAction = f.ButtonAction,
            regexPattern = f.RegexPattern,
            validationMessage = f.ValidationMessage,
            lookupFormId = f.LookupFormId,
            lookupFieldKey = f.LookupFieldKey,
            sectionColumns = f.FieldType == "section" ? f.SectionColumns : null,
            columnIndex = f.ColumnIndex,
            customJs = f.CustomJs,
            cssClass = f.CssClass,
            customId = f.CustomId,
            // Real JSON arrays (not serialized strings) — the SP reads AS JSON.
            customAttributesJson = f.CustomAttributes.Count > 0
                ? (object)f.CustomAttributes.Select(a => new { name = a.Name, value = a.Value }).ToList()
                : null,
            validationRulesJson = f.ValidationRules.Count > 0
                ? (object)f.ValidationRules.Select(r => new { pattern = r.Pattern, message = r.Message }).ToList()
                : null,
            inputMask = f.InputMask,
            parentKey = f.ParentKey,
            showBorder = f.ShowBorder,
            showDivider = f.ShowDivider,
            showInfoIcon = f.ShowInfoIcon,
            infoText = f.InfoText,
            minLength = f.MinLength,
            maxLength = f.MaxLength,
            minValue = f.MinValue,
            maxValue = f.MaxValue,
            accept = f.Accept,
            choiceLayout = string.IsNullOrWhiteSpace(f.ChoiceLayout) ? "Vertical" : f.ChoiceLayout,
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
        p.Add("@IsMultiStep", request.IsMultiStep);
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

    private static List<DynamicFormGridColumnDto> ParseGridColumns(string? optionsJson)
    {
        if (string.IsNullOrWhiteSpace(optionsJson)) return new();
        try
        {
            return JsonSerializer.Deserialize<List<DynamicFormGridColumnDto>>(optionsJson,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new();
        }
        catch (JsonException)
        {
            return new();
        }
    }

    /* Parent resolution: forms saved by the current builder carry an explicit
       ParentKey on every nested field (null = top level). Older rows have
       ParentKey null everywhere; for those, the parent is derived from field
       order (a field belonged to the section above it). As soon as ANY field
       carries a parent, the form is treated as explicit and nulls mean root. */
    private static List<FieldRow> ResolveParents(List<FieldRow> fields)
    {
        if (fields.Any(f => f.ParentKey is not null)) return fields;
        string? lastSectionKey = null;
        foreach (var f in fields)
        {
            if (f.FieldType == "section") { lastSectionKey = f.FieldKey; }
            else { f.ParentKey = lastSectionKey; }
        }
        return fields;
    }

    private static List<DynamicFormCustomAttributeDto> ParseCustomAttributes(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return new();
        try
        {
            return JsonSerializer.Deserialize<List<DynamicFormCustomAttributeDto>>(json,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new();
        }
        catch { return new(); }
    }

    private static List<DynamicFormValidationRuleDto> ParseValidationRules(string? json)
    {
        if (string.IsNullOrWhiteSpace(json)) return new();
        try
        {
            return JsonSerializer.Deserialize<List<DynamicFormValidationRuleDto>>(json,
                new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new();
        }
        catch { return new(); }
    }

    /* ---------------- submission entries ---------------- */

    private sealed class SubmissionRow
    {
        public int SubmissionId { get; set; }
        public int FormId { get; set; }
        public int? SubmittedBy { get; set; }
        public string? SubmittedByName { get; set; }
        public DateTime SubmittedAt { get; set; }
        public int ValueCount { get; set; }
    }

    private sealed class SubmissionValueRow
    {
        public string FieldKey { get; set; } = string.Empty;
        public string? ValueJson { get; set; }
    }

    public async Task<int> SubmitAsync(
        int formId, int? submittedBy, IReadOnlyList<(string FieldKey, string ValueJson)> values)
    {
        // The SP takes one JSON array [{fieldKey, valueJson}]; valueJson is
        // itself JSON text, so it is carried as a string and re-encoded
        // here — the SP stores it back as the original JSON text.
        var payload = values.Select(v => new { fieldKey = v.FieldKey, valueJson = v.ValueJson }).ToList();
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@FormId", formId);
        p.Add("@SubmittedBy", submittedBy);
        p.Add("@ValuesJson", JsonSerializer.Serialize(payload));
        p.Add("@NewSubmissionId", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await connection.ExecuteAsync(
            StoredProcedures.DynamicFormSubmissionSubmit, p, commandType: CommandType.StoredProcedure);
        return p.Get<int>("@NewSubmissionId");
    }

    public async Task<IReadOnlyList<DynamicFormSubmissionListItemDto>> GetSubmissionsByFormAsync(int formId)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@FormId", formId);
        var rows = await connection.QueryAsync<SubmissionRow>(
            StoredProcedures.DynamicFormSubmissionGetByForm, p, commandType: CommandType.StoredProcedure);
        return rows.Select(r => new DynamicFormSubmissionListItemDto
        {
            SubmissionId = r.SubmissionId, FormId = r.FormId,
            SubmittedBy = r.SubmittedBy, SubmittedByName = r.SubmittedByName,
            SubmittedAt = r.SubmittedAt, ValueCount = r.ValueCount
        }).ToList();
    }

    public async Task<DynamicFormSubmissionDetailDto?> GetSubmissionByIdAsync(int submissionId)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@SubmissionId", submissionId);
        using var multi = await connection.QueryMultipleAsync(
            StoredProcedures.DynamicFormSubmissionGetById, p, commandType: CommandType.StoredProcedure);
        var header = await multi.ReadSingleOrDefaultAsync<SubmissionRow>();
        if (header is null) return null;
        var values = await multi.ReadAsync<SubmissionValueRow>();
        var dict = new Dictionary<string, JsonElement>(StringComparer.OrdinalIgnoreCase);
        foreach (var v in values)
        {
            dict[v.FieldKey] = ParseStoredValue(v.ValueJson);
        }
        return new DynamicFormSubmissionDetailDto
        {
            SubmissionId = header.SubmissionId, FormId = header.FormId,
            SubmittedBy = header.SubmittedBy, SubmittedByName = header.SubmittedByName,
            SubmittedAt = header.SubmittedAt, Values = dict
        };
    }

    public async Task DeleteSubmissionAsync(int submissionId, int performedBy)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@SubmissionId", submissionId);
        p.Add("@PerformedBy", performedBy);
        await connection.ExecuteAsync(
            StoredProcedures.DynamicFormSubmissionDelete, p, commandType: CommandType.StoredProcedure);
    }

    public async Task<IReadOnlyList<string>> GetFieldValuesAsync(int formId, string fieldKey)
    {
        using var connection = context.CreateConnection();
        var p = new DynamicParameters();
        p.Add("@FormId", formId);
        p.Add("@FieldKey", fieldKey);
        var rows = await connection.QueryAsync<string>(
            StoredProcedures.DynamicFormSubmissionGetFieldValues, p, commandType: CommandType.StoredProcedure);
        return rows.Where(r => r is not null).ToList();
    }

    // Stored ValueJson back to a JsonElement. A corrupt row degrades to
    // its raw text instead of failing the whole entry.
    private static JsonElement ParseStoredValue(string? valueJson)
    {
        if (string.IsNullOrWhiteSpace(valueJson)) return default;
        try
        {
            using var doc = JsonDocument.Parse(valueJson);
            return doc.RootElement.Clone();
        }
        catch
        {
            using var doc = JsonDocument.Parse(JsonSerializer.Serialize(valueJson));
            return doc.RootElement.Clone();
        }
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
