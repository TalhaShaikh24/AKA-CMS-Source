using System.Text.Json;
using System.Text.RegularExpressions;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using FluentValidation;
using FluentValidation.Results;
using Microsoft.Extensions.Options;

namespace AKA.CMS.Application.Services;

public sealed partial class DynamicFormService(
    IDynamicFormRepository repository,
    IOptions<FileStorageOptions> storageOptions) : IDynamicFormService
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

    /// <summary>Options for a lookup field. Once the source form has
    /// submissions, the distinct values actually submitted for that field
    /// win — a lookup then offers real entered values, not just the
    /// configured list. With no submissions yet, the source field's
    /// configured options are returned (empty for non-option fields).</summary>
    public async Task<IReadOnlyList<DynamicFormFieldOptionDto>> GetLookupOptionsAsync(int formId, string fieldKey)
    {
        var form = await GetByIdAsync(formId);
        var field = form.Fields.FirstOrDefault(f =>
            string.Equals(f.FieldKey, fieldKey, StringComparison.OrdinalIgnoreCase))
            ?? throw new NotFoundException($"Field '{fieldKey}' not found in form {formId}.");

        var submitted = await repository.GetFieldValuesAsync(formId, field.FieldKey);
        var distinct = new List<string>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var raw in submitted)
        {
            foreach (var value in FlattenStoredValue(raw))
            {
                if (!string.IsNullOrWhiteSpace(value) && seen.Add(value.Trim()))
                    distinct.Add(value.Trim());
            }
        }
        if (distinct.Count > 0)
        {
            distinct.Sort(StringComparer.OrdinalIgnoreCase);
            return distinct.Select(v => new DynamicFormFieldOptionDto { Value = v, Label = v }).ToList();
        }

        return DynamicFormFieldTypes.HasOptions(field.FieldType)
            ? field.Options
            : new List<DynamicFormFieldOptionDto>();
    }

    // One stored value (JSON text) flattened to plain display strings:
    // a string stays itself, a number/boolean becomes its text, an array
    // contributes each scalar element, anything else is skipped.
    private static List<string> FlattenStoredValue(string raw)
    {
        var values = new List<string>();
        try
        {
            using var doc = JsonDocument.Parse(raw);
            var root = doc.RootElement;
            if (root.ValueKind == JsonValueKind.Array)
            {
                foreach (var el in root.EnumerateArray())
                {
                    if (el.ValueKind == JsonValueKind.String) values.Add(el.GetString()!);
                    else if (el.ValueKind is JsonValueKind.Number or JsonValueKind.True or JsonValueKind.False)
                        values.Add(el.GetRawText());
                }
            }
            else if (root.ValueKind == JsonValueKind.String)
            {
                values.Add(root.GetString()!);
            }
            else if (root.ValueKind is JsonValueKind.Number or JsonValueKind.True or JsonValueKind.False)
            {
                values.Add(root.GetRawText());
            }
        }
        catch
        {
            // A corrupt row is ignored rather than breaking the lookup.
        }
        return values;
    }

    /* ---------------- submission entries ---------------- */

    public async Task<DynamicFormSubmissionDetailDto> SubmitAsync(
        int formId, Dictionary<string, JsonElement> values,
        IReadOnlyList<SubmissionFileUpload> files, int submittedBy)
    {
        var form = await GetByIdAsync(formId);
        if (!form.IsActive)
            throw new InvalidDomainValueException("This form is inactive and does not accept submissions.");

        // Case-insensitive lookup: JSON keys arrive exactly as the client
        // sent them, field keys are defined lowercase.
        var byKey = new Dictionary<string, JsonElement>(StringComparer.OrdinalIgnoreCase);
        foreach (var kv in values) byKey[kv.Key] = kv.Value;
        var fileByKey = files
            .GroupBy(f => f.FieldKey, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);

        ValidateSubmission(form, byKey, fileByKey);

        // Files are written first, under one folder per entry, so the
        // stored value is the file's path. If the DB save then fails,
        // the folder is removed again — no orphaned files, no row
        // pointing at a file that never landed.
        var uploadsRoot = ResolveUploadsPath();
        var folderToken = Guid.NewGuid().ToString("N");
        var folder = Path.Combine(uploadsRoot, "forms", formId.ToString(), folderToken);
        var stored = new List<(string FieldKey, string ValueJson)>();
        try
        {
            foreach (var field in form.Fields)
            {
                if (DynamicFormFieldTypes.IsStatic(field.FieldType)) continue;
                if (field.FieldType == "file")
                {
                    if (!fileByKey.TryGetValue(field.FieldKey, out var upload)) continue;
                    Directory.CreateDirectory(folder);
                    var safeName = SanitizeFileName(upload.FileName);
                    var storedName = $"{Guid.NewGuid():N}_{safeName}";
                    var fullPath = Path.Combine(folder, storedName);
                    await using (var stream = new FileStream(fullPath, FileMode.CreateNew, FileAccess.Write))
                    {
                        await upload.Content.CopyToAsync(stream);
                    }
                    var relative = $"forms/{formId}/{folderToken}/{storedName}";
                    stored.Add((field.FieldKey, JsonSerializer.Serialize(relative)));
                    continue;
                }
                if (byKey.TryGetValue(field.FieldKey, out var element))
                    stored.Add((field.FieldKey, element.GetRawText()));
            }

            var submissionId = await repository.SubmitAsync(formId, submittedBy, stored);
            return await GetSubmissionAsync(submissionId);
        }
        catch
        {
            TryDeleteFolder(folder);
            throw;
        }
    }

    public async Task<IReadOnlyList<DynamicFormSubmissionListItemDto>> GetSubmissionsAsync(int formId)
    {
        _ = await GetByIdAsync(formId);
        return await repository.GetSubmissionsByFormAsync(formId);
    }

    public async Task<DynamicFormSubmissionDetailDto> GetSubmissionAsync(int submissionId)
        => await repository.GetSubmissionByIdAsync(submissionId)
           ?? throw new NotFoundException($"Submission {submissionId} not found.");

    public async Task DeleteSubmissionAsync(int submissionId, int performedBy)
    {
        // Read first: file values hold stored paths, which must be
        // deleted from disk after the row goes.
        var detail = await GetSubmissionAsync(submissionId);
        var form = await GetByIdAsync(detail.FormId);
        var fileKeys = form.Fields
            .Where(f => f.FieldType == "file")
            .Select(f => f.FieldKey)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);

        await repository.DeleteSubmissionAsync(submissionId, performedBy);

        var uploadsRoot = ResolveUploadsPath();
        var rootFull = Path.GetFullPath(uploadsRoot);
        var folders = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var kv in detail.Values)
        {
            if (!fileKeys.Contains(kv.Key) || kv.Value.ValueKind != JsonValueKind.String) continue;
            var relative = kv.Value.GetString();
            if (string.IsNullOrWhiteSpace(relative)) continue;
            var full = Path.GetFullPath(Path.Combine(rootFull, relative));
            if (!full.StartsWith(rootFull + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase)
                && !string.Equals(full, rootFull, StringComparison.OrdinalIgnoreCase)) continue;
            try { if (File.Exists(full)) File.Delete(full); } catch { /* best effort */ }
            var dir = Path.GetDirectoryName(full);
            if (!string.IsNullOrEmpty(dir)) folders.Add(dir);
        }
        foreach (var dir in folders)
        {
            try { if (Directory.Exists(dir) && !Directory.EnumerateFileSystemEntries(dir).Any()) Directory.Delete(dir); } catch { /* best effort */ }
        }
    }

    public async Task<(string FileName, string ContentType, string StoragePath)> GetSubmissionFileAsync(
        int submissionId, string fieldKey)
    {
        var detail = await GetSubmissionAsync(submissionId);
        var form = await GetByIdAsync(detail.FormId);
        _ = form.Fields.FirstOrDefault(f => f.FieldType == "file"
                && string.Equals(f.FieldKey, fieldKey, StringComparison.OrdinalIgnoreCase))
            ?? throw new NotFoundException($"File field '{fieldKey}' not found in form {detail.FormId}.");
        if (!detail.Values.TryGetValue(fieldKey, out var value) || value.ValueKind != JsonValueKind.String)
            throw new NotFoundException($"Submission {submissionId} has no file for field '{fieldKey}'.");
        var relative = value.GetString();
        if (string.IsNullOrWhiteSpace(relative))
            throw new NotFoundException($"Submission {submissionId} has no file for field '{fieldKey}'.");

        // The stored path must stay inside the uploads root — a stored
        // value is never trusted as an absolute or escaping path.
        var rootFull = ResolveUploadsPath();
        var full = Path.GetFullPath(Path.Combine(rootFull, relative));
        if (!full.StartsWith(rootFull + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
            throw new NotFoundException($"Submission {submissionId} has no file for field '{fieldKey}'.");
        if (!File.Exists(full))
            throw new NotFoundException($"The uploaded file for submission {submissionId} is missing on disk.");

        var storedName = Path.GetFileName(full);
        var underscore = storedName.IndexOf('_');
        var original = underscore >= 0 ? storedName[(underscore + 1)..] : storedName;
        return (original, ContentTypeFor(Path.GetExtension(full)), full);
    }

    private static string ContentTypeFor(string extension) => extension.ToLowerInvariant() switch
    {
        ".pdf" => "application/pdf",
        ".png" => "image/png",
        ".jpg" or ".jpeg" => "image/jpeg",
        ".gif" => "image/gif",
        ".webp" => "image/webp",
        ".txt" => "text/plain",
        ".csv" => "text/csv",
        ".doc" => "application/msword",
        ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        ".xls" => "application/vnd.ms-excel",
        ".xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        ".zip" => "application/zip",
        _ => "application/octet-stream"
    };

    // Server-side mirror of the renderer's validateFields: required, email
    // format, regex patterns + custom messages, length and number ranges,
    // and file Accept. Failures carry the field key so the renderer can
    // show each message inline under its own field.
    private static void ValidateSubmission(
        DynamicFormDetailDto form,
        Dictionary<string, JsonElement> byKey,
        Dictionary<string, SubmissionFileUpload> fileByKey)
    {
        var failures = new List<ValidationFailure>();
        foreach (var field in form.Fields)
        {
            if (DynamicFormFieldTypes.IsStatic(field.FieldType) || field.FieldType == "hidden") continue;

            if (field.FieldType == "file")
            {
                var upload = fileByKey.TryGetValue(field.FieldKey, out var u) ? u : null;
                if (field.IsRequired && upload is null)
                    failures.Add(new ValidationFailure(field.FieldKey, $"{field.Label} is required."));
                else if (upload is not null && !AcceptAllows(field.Accept, upload.FileName, upload.ContentType))
                    failures.Add(new ValidationFailure(field.FieldKey, $"File type not allowed for {field.Label}."));
                continue;
            }

            var present = byKey.TryGetValue(field.FieldKey, out var value);
            if (!present) value = default;
            if (IsSubmissionEmpty(field, value))
            {
                if (field.IsRequired)
                    failures.Add(new ValidationFailure(field.FieldKey, $"{field.Label} is required."));
                continue;
            }

            var text = value.ValueKind == JsonValueKind.String ? value.GetString() ?? string.Empty : null;
            if (field.FieldType == "email" && text is not null
                && !Regex.IsMatch(text, @"^[^\s@]+@[^\s@]+\.[^\s@]{2,}$"))
            {
                failures.Add(new ValidationFailure(field.FieldKey, "Please enter a valid email address."));
                continue;
            }
            if (text is not null)
            {
                if (field.MinLength is int min && text.Length < min)
                    failures.Add(new ValidationFailure(field.FieldKey, $"{field.Label} must be at least {min} characters."));
                if (field.MaxLength is int max && text.Length > max)
                    failures.Add(new ValidationFailure(field.FieldKey, $"{field.Label} must be at most {max} characters."));
            }
            if (value.ValueKind == JsonValueKind.Number && value.TryGetDecimal(out var number))
            {
                if (field.MinValue is decimal minV && number < minV)
                    failures.Add(new ValidationFailure(field.FieldKey, $"{field.Label} must be at least {minV}."));
                if (field.MaxValue is decimal maxV && number > maxV)
                    failures.Add(new ValidationFailure(field.FieldKey, $"{field.Label} must be at most {maxV}."));
            }
            if (text is not null)
            {
                foreach (var pattern in Prepend(field.RegexPattern, field.ValidationRules.Select(r => r.Pattern)))
                {
                    if (string.IsNullOrWhiteSpace(pattern)) continue;
                    if (!Regex.IsMatch(text, pattern))
                    {
                        var rule = field.ValidationRules.FirstOrDefault(r => r.Pattern == pattern);
                        failures.Add(new ValidationFailure(field.FieldKey,
                            rule?.Message ?? field.ValidationMessage ?? $"Please enter a valid value for {field.Label}."));
                        break;
                    }
                }
            }
        }
        if (failures.Count > 0) throw new ValidationException(failures);
    }

    private static IEnumerable<string?> Prepend(string? first, IEnumerable<string> rest)
    {
        yield return first;
        foreach (var item in rest) yield return item;
    }

    // Same emptiness rules as the renderer: an empty string, an unchecked
    // box, an empty selection, or a grid with no filled row all count as
    // "not answered". A number (including 0) counts as answered.
    private static bool IsSubmissionEmpty(DynamicFormFieldDto field, JsonElement value)
    {
        if (value.ValueKind == JsonValueKind.Undefined || value.ValueKind == JsonValueKind.Null) return true;
        return value.ValueKind switch
        {
            JsonValueKind.String => string.IsNullOrWhiteSpace(value.GetString()),
            JsonValueKind.False => true,
            JsonValueKind.Array => field.FieldType == "grid"
                ? !value.EnumerateArray().Any(row => row.ValueKind == JsonValueKind.Object
                    && row.EnumerateObject().Any(c =>
                        c.Value.ValueKind == JsonValueKind.String
                            ? !string.IsNullOrWhiteSpace(c.Value.GetString())
                            : c.Value.ValueKind != JsonValueKind.Null))
                : value.GetArrayLength() == 0,
            _ => false
        };
    }

    private static bool AcceptAllows(string? accept, string fileName, string contentType)
    {
        if (string.IsNullOrWhiteSpace(accept)) return true;
        var ext = Path.GetExtension(fileName).ToLowerInvariant();
        var type = (contentType ?? string.Empty).ToLowerInvariant();
        foreach (var part in accept.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var p = part.ToLowerInvariant();
            if (p.StartsWith('.') && p == ext) return true;
            if (p.EndsWith("/*") && type.StartsWith(p[..^1], StringComparison.Ordinal)) return true;
            if (p == type) return true;
        }
        return false;
    }

    private string ResolveUploadsPath()
    {
        var path = storageOptions.Value.UploadsPath;
        if (string.IsNullOrWhiteSpace(path))
            throw new InvalidDomainValueException("File storage is not configured.");
        return Path.GetFullPath(Environment.ExpandEnvironmentVariables(path));
    }

    private static string SanitizeFileName(string fileName)
    {
        var name = Path.GetFileName(fileName ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(name))
            throw new InvalidDomainValueException("A file name is required.");
        var invalid = Path.GetInvalidFileNameChars();
        name = new string(name.Where(c => !invalid.Contains(c)).ToArray()).Trim();
        if (string.IsNullOrWhiteSpace(name) || name.Length > 200)
            throw new InvalidDomainValueException("The file name is not valid.");
        return name;
    }

    private static void TryDeleteFolder(string folder)
    {
        try { if (Directory.Exists(folder)) Directory.Delete(folder, recursive: true); } catch { /* best effort */ }
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
