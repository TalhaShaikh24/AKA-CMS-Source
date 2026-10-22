using System.Text.RegularExpressions;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;

namespace AKA.CMS.Application.Services;

public sealed partial class DynamicFormService(IDynamicFormRepository repository) : IDynamicFormService
{
    public Task<IReadOnlyList<DynamicFormListItemDto>> GetAllAsync() => repository.GetAllAsync();

    public async Task<DynamicFormDetailDto> GetByIdAsync(int formId)
        => await repository.GetByIdAsync(formId)
           ?? throw new NotFoundException($"Form {formId} not found.");

    public async Task<DynamicFormDetailDto> CreateAsync(SaveDynamicFormRequest request, int performedBy)
    {
        Validate(request);
        await ValidateLookupsAsync(request, null);
        await EnsureKeyAvailableAsync(request.FormKey, null);
        var id = await repository.SaveAsync(0, request, performedBy);
        return await GetByIdAsync(id);
    }

    public async Task<DynamicFormDetailDto> UpdateAsync(int formId, SaveDynamicFormRequest request, int performedBy)
    {
        _ = await GetByIdAsync(formId);
        Validate(request);
        await ValidateLookupsAsync(request, formId);
        await EnsureKeyAvailableAsync(request.FormKey, formId);
        var id = await repository.SaveAsync(formId, request, performedBy);
        return await GetByIdAsync(id);
    }

    /// <summary>Options for a lookup field: the configured options of the
    /// referenced field in the source form. Non-option source fields (and
    /// forms without submissions yet) yield an empty list.</summary>
    public async Task<IReadOnlyList<DynamicFormFieldOptionDto>> GetLookupOptionsAsync(int formId, string fieldKey)
    {
        var form = await GetByIdAsync(formId);
        var field = form.Fields.FirstOrDefault(f =>
            string.Equals(f.FieldKey, fieldKey, StringComparison.OrdinalIgnoreCase))
            ?? throw new NotFoundException($"Field '{fieldKey}' not found in form {formId}.");
        return DynamicFormFieldTypes.HasOptions(field.FieldType)
            ? field.Options
            : new List<DynamicFormFieldOptionDto>();
    }

    private async Task ValidateLookupsAsync(SaveDynamicFormRequest request, int? selfFormId)
    {
        foreach (var field in request.Fields.Where(f => f.FieldType == "lookup"))
        {
            if (field.LookupFormId is null or <= 0 || string.IsNullOrWhiteSpace(field.LookupFieldKey))
                throw new InvalidDomainValueException($"Lookup field '{field.FieldKey}' needs a source form and source field.");
            if (selfFormId is not null && field.LookupFormId == selfFormId)
                throw new InvalidDomainValueException($"Lookup field '{field.FieldKey}' cannot look up its own form.");
            var source = await repository.GetByIdAsync(field.LookupFormId.Value)
                ?? throw new InvalidDomainValueException($"Lookup field '{field.FieldKey}' points at form {field.LookupFormId}, which does not exist.");
            if (!source.Fields.Any(f => string.Equals(f.FieldKey, field.LookupFieldKey, StringComparison.OrdinalIgnoreCase)))
                throw new InvalidDomainValueException($"Lookup field '{field.FieldKey}' points at field '{field.LookupFieldKey}', which does not exist in form '{source.FormKey}'.");
        }
    }

    private async Task EnsureKeyAvailableAsync(string formKey, int? exceptFormId)
    {
        var all = await repository.GetAllAsync();
        var clash = all.FirstOrDefault(f =>
            string.Equals(f.FormKey, formKey.Trim(), StringComparison.OrdinalIgnoreCase)
            && f.FormId != exceptFormId);
        if (clash is not null)
            throw new ConflictException($"A form with key '{formKey}' already exists.");
    }

    public async Task DeleteAsync(int formId, int performedBy)
    {
        _ = await GetByIdAsync(formId);
        await repository.DeleteAsync(formId, performedBy);
    }

    private static void Validate(SaveDynamicFormRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Title))
            throw new InvalidDomainValueException("Title is required.");
        if (string.IsNullOrWhiteSpace(request.FormKey) || !KeyPattern().IsMatch(request.FormKey.Trim()))
            throw new InvalidDomainValueException("FormKey is required and may only contain lowercase letters, digits and hyphens.");

        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var field in request.Fields)
        {
            if (string.IsNullOrWhiteSpace(field.FieldKey) || !KeyPattern().IsMatch(field.FieldKey.Trim()))
                throw new InvalidDomainValueException($"Field key '{field.FieldKey}' is invalid (lowercase letters, digits and hyphens only).");
            if (!seen.Add(field.FieldKey.Trim()))
                throw new InvalidDomainValueException($"Duplicate field key '{field.FieldKey}'.");
            if (string.IsNullOrWhiteSpace(field.Label))
                throw new InvalidDomainValueException($"Field '{field.FieldKey}' needs a label.");
            if (!DynamicFormFieldTypes.All.Contains(field.FieldType))
                throw new InvalidDomainValueException($"Field '{field.FieldKey}' has unsupported type '{field.FieldType}'.");
            if (DynamicFormFieldTypes.HasOptions(field.FieldType) && field.Options.Count == 0)
                throw new InvalidDomainValueException($"Field '{field.FieldKey}' needs at least one option.");
            if (field.ColumnSpan is < 1 or > 12)
                throw new InvalidDomainValueException($"Field '{field.FieldKey}' column span must be between 1 and 12.");
            if (field.ChoiceLayout is not null and not "Vertical" and not "Horizontal")
                throw new InvalidDomainValueException($"Field '{field.FieldKey}' choice layout must be 'Vertical' or 'Horizontal'.");
            if (field.FieldType == "button" && field.ButtonAction is not null and not "submit" and not "reset" and not "button")
                throw new InvalidDomainValueException($"Button '{field.FieldKey}' action must be 'submit', 'reset' or 'button'.");
            if (!string.IsNullOrWhiteSpace(field.RegexPattern))
            {
                if (!DynamicFormFieldTypes.SupportsRegex(field.FieldType))
                    throw new InvalidDomainValueException($"Field '{field.FieldKey}' type does not support a regex pattern.");
                try { _ = new Regex(field.RegexPattern); }
                catch (ArgumentException)
                {
                    throw new InvalidDomainValueException($"Field '{field.FieldKey}' has an invalid regex pattern.");
                }
            }
            if (field.FieldType == "grid")
            {
                if (field.GridColumns.Count == 0)
                    throw new InvalidDomainValueException($"Grid '{field.FieldKey}' needs at least one column.");
                var colKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                foreach (var col in field.GridColumns)
                {
                    if (string.IsNullOrWhiteSpace(col.Key) || !KeyPattern().IsMatch(col.Key.Trim()))
                        throw new InvalidDomainValueException($"Grid '{field.FieldKey}' has a column with an invalid key '{col.Key}'.");
                    if (!colKeys.Add(col.Key.Trim()))
                        throw new InvalidDomainValueException($"Grid '{field.FieldKey}' has duplicate column key '{col.Key}'.");
                    if (string.IsNullOrWhiteSpace(col.Label))
                        throw new InvalidDomainValueException($"Grid '{field.FieldKey}' column '{col.Key}' needs a label.");
                    if (!DynamicFormFieldTypes.GridColumnTypes.Contains(col.Type))
                        throw new InvalidDomainValueException($"Grid '{field.FieldKey}' column '{col.Key}' has unsupported type '{col.Type}'.");
                    if (col.Type == "select" && col.Options.Count == 0)
                        throw new InvalidDomainValueException($"Grid '{field.FieldKey}' column '{col.Key}' needs at least one option.");
                }
            }
        }

        // Every form must carry exactly one submit button — it is what the
        // (future) submission pipeline will post through.
        var submitCount = request.Fields.Count(f =>
            f.FieldType == "button" && string.Equals(f.ButtonAction, "submit", StringComparison.OrdinalIgnoreCase));
        if (submitCount != 1)
            throw new InvalidDomainValueException($"The form must contain exactly one Submit button (found {submitCount}). Add a Button field and set its type to Submit.");
    }

    [GeneratedRegex("^[a-z0-9][a-z0-9-]*$")]
    private static partial Regex KeyPattern();
}
