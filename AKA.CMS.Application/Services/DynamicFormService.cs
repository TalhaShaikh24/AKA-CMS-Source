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
            if (field.SectionColumns is int secCols && (secCols < 1 || secCols > 4))
                throw new InvalidDomainValueException($"Section '{field.FieldKey}' column count must be between 1 and 4.");
            if (field.ColumnIndex is int colIdx && (colIdx < 0 || colIdx > 3))
                throw new InvalidDomainValueException($"Field '{field.FieldKey}' column index must be between 0 and 3.");
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
            // Advanced options: multiple regex rules, custom attributes,
            // custom id/class — validated here so bad values never persist.
            foreach (var rule in field.ValidationRules)
            {
                if (string.IsNullOrWhiteSpace(rule.Pattern))
                    throw new InvalidDomainValueException($"Field '{field.FieldKey}' has a validation rule without a pattern.");
                if (!DynamicFormFieldTypes.SupportsRegex(field.FieldType))
                    throw new InvalidDomainValueException($"Field '{field.FieldKey}' type '{field.FieldType}' does not support validation rules.");
                try { _ = new Regex(rule.Pattern); }
                catch (ArgumentException)
                {
                    throw new InvalidDomainValueException($"Field '{field.FieldKey}' has an invalid validation-rule pattern '{rule.Pattern}'.");
                }
            }
            var seenAttrs = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var attr in field.CustomAttributes)
            {
                if (string.IsNullOrWhiteSpace(attr.Name) || !AttributeNamePattern().IsMatch(attr.Name.Trim())
                    || attr.Name.Trim().StartsWith("on", StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDomainValueException($"Field '{field.FieldKey}' has an invalid custom attribute name '{attr.Name}'.");
                if (!seenAttrs.Add(attr.Name.Trim()))
                    throw new InvalidDomainValueException($"Field '{field.FieldKey}' repeats the custom attribute '{attr.Name}'.");
            }
            if (!string.IsNullOrWhiteSpace(field.CustomId) && !CustomIdPattern().IsMatch(field.CustomId.Trim()))
                throw new InvalidDomainValueException($"Field '{field.FieldKey}' has an invalid custom ID '{field.CustomId}' (letters, digits, hyphens, underscores; must start with a letter).");
            if (!string.IsNullOrWhiteSpace(field.CssClass) && !CssClassPattern().IsMatch(field.CssClass.Trim()))
                throw new InvalidDomainValueException($"Field '{field.FieldKey}' has an invalid CSS class '{field.CssClass}'.");
            if (field.CustomJs is { Length: > 8000 })
                throw new InvalidDomainValueException($"Field '{field.FieldKey}' custom function is too long (max 8000 characters).");
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

        // Nesting: a field's parent must be a section of the same form, with
        // no cycles and at most 3 levels of nesting.
        var byKey = request.Fields
            .GroupBy(f => f.FieldKey, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);
        foreach (var field in request.Fields)
        {
            if (string.IsNullOrWhiteSpace(field.ParentKey)) continue;
            if (string.Equals(field.ParentKey, field.FieldKey, StringComparison.OrdinalIgnoreCase))
                throw new InvalidDomainValueException($"Field '{field.FieldKey}' cannot be its own parent.");
            if (!byKey.TryGetValue(field.ParentKey, out var parent) || parent.FieldType != "section")
                throw new InvalidDomainValueException($"Field '{field.FieldKey}' has parent '{field.ParentKey}', which is not a section of this form.");
            var depth = 0;
            var seenChain = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { field.FieldKey };
            var cursor = parent;
            while (cursor is not null)
            {
                if (!seenChain.Add(cursor.FieldKey))
                    throw new InvalidDomainValueException($"Field '{field.FieldKey}' creates a section nesting cycle.");
                depth++;
                if (depth > 3)
                    throw new InvalidDomainValueException($"Field '{field.FieldKey}' is nested too deeply (max 3 levels).");
                cursor = cursor.ParentKey is not null && byKey.TryGetValue(cursor.ParentKey, out var next) ? next : null;
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

    [GeneratedRegex("^[a-zA-Z][a-zA-Z0-9_-]*$")]
    private static partial Regex AttributeNamePattern();

    [GeneratedRegex("^[A-Za-z][A-Za-z0-9_-]*$")]
    private static partial Regex CustomIdPattern();

    [GeneratedRegex("^[A-Za-z0-9 _-]+$")]
    private static partial Regex CssClassPattern();
}
