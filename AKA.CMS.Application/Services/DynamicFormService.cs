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
        await EnsureKeyAvailableAsync(request.FormKey, null);
        var id = await repository.SaveAsync(0, request, performedBy);
        return await GetByIdAsync(id);
    }

    public async Task<DynamicFormDetailDto> UpdateAsync(int formId, SaveDynamicFormRequest request, int performedBy)
    {
        _ = await GetByIdAsync(formId);
        Validate(request);
        await EnsureKeyAvailableAsync(request.FormKey, formId);
        var id = await repository.SaveAsync(formId, request, performedBy);
        return await GetByIdAsync(id);
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
        }
    }

    [GeneratedRegex("^[a-z0-9][a-z0-9-]*$")]
    private static partial Regex KeyPattern();
}
