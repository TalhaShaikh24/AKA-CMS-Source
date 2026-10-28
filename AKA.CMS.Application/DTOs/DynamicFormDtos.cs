using System.Text.Json;

namespace AKA.CMS.Application.DTOs;

/// <summary>One field option for select / multiselect / radio / checkbox-group fields.</summary>
public sealed class DynamicFormFieldOptionDto
{
    public string Value { get; set; } = string.Empty;
    public string Label { get; set; } = string.Empty;
}

/// <summary>One column of a grid/table field. Stored inside OptionsJson as
/// [{key,label,type,options}] when the field type is 'grid'.</summary>
public sealed class DynamicFormGridColumnDto
{
    public string Key { get; set; } = string.Empty;
    public string Label { get; set; } = string.Empty;
    /// <summary>text | number | date | select</summary>
    public string Type { get; set; } = "text";
    public List<DynamicFormFieldOptionDto> Options { get; set; } = new();
}

/// <summary>One custom attribute (name/value) applied to a field's control.</summary>
public sealed class DynamicFormCustomAttributeDto
{
    public string Name { get; set; } = string.Empty;
    public string Value { get; set; } = string.Empty;
}

/// <summary>One extra regex validation rule with its own error message.</summary>
public sealed class DynamicFormValidationRuleDto
{
    public string Pattern { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
}

public sealed class DynamicFormFieldDto
{
    public int FieldId { get; set; }
    public string FieldKey { get; set; } = string.Empty;
    public string Label { get; set; } = string.Empty;
    public string FieldType { get; set; } = "text";
    public string? Placeholder { get; set; }
    public string? HelpText { get; set; }
    public bool IsRequired { get; set; }
    public string? DefaultValue { get; set; }
    public List<DynamicFormFieldOptionDto> Options { get; set; } = new();
    public int? MinLength { get; set; }
    public int? MaxLength { get; set; }
    public decimal? MinValue { get; set; }
    public decimal? MaxValue { get; set; }
    public string? Accept { get; set; }
    /// <summary>For radio / checkbox groups: 'Vertical' (default) or 'Horizontal'.</summary>
    public string? ChoiceLayout { get; set; }
    /// <summary>For button fields: 'submit' | 'reset' | 'button'.</summary>
    public string? ButtonAction { get; set; }
    /// <summary>Custom regex the value must match (text-like fields).</summary>
    public string? RegexPattern { get; set; }
    /// <summary>Error message shown when the regex does not match.</summary>
    public string? ValidationMessage { get; set; }
    /// <summary>For lookup fields: the other form whose field supplies the options.</summary>
    public int? LookupFormId { get; set; }
    /// <summary>For lookup fields: the field key in the source form.</summary>
    public string? LookupFieldKey { get; set; }
    /// <summary>For grid fields: the table columns (stored in OptionsJson).</summary>
    public List<DynamicFormGridColumnDto> GridColumns { get; set; } = new();
    /// <summary>For section fields: column count (1-4) for the Elementor-style
    /// column layout. Null = legacy span-grid layout.</summary>
    public int? SectionColumns { get; set; }
    /// <summary>For fields inside a column-layout section: which column
    /// (0-based) the field sits in. Null = first column.</summary>
    public int? ColumnIndex { get; set; }
    /// <summary>Key of the section this field belongs to; null = the form's
    /// top level. A section may itself have a parent (nested section).</summary>
    public string? ParentKey { get; set; }
    /// <summary>Section border visibility; null = default (shown at the top
    /// level, hidden for a child/nested section).</summary>
    public bool? ShowBorder { get; set; }
    /// <summary>Divider under the section title; null = default (same rule).</summary>
    public bool? ShowDivider { get; set; }
    /// <summary>Custom JavaScript run when the field changes (button: on click).</summary>
    public string? CustomJs { get; set; }
    /// <summary>Extra CSS class(es) added to the field wrapper.</summary>
    public string? CssClass { get; set; }
    /// <summary>Custom element id for the field control.</summary>
    public string? CustomId { get; set; }
    /// <summary>Custom attributes applied to the field control.</summary>
    public List<DynamicFormCustomAttributeDto> CustomAttributes { get; set; } = new();
    /// <summary>Extra regex validation rules, each with its own message.</summary>
    public List<DynamicFormValidationRuleDto> ValidationRules { get; set; } = new();
    /// <summary>Input mask pattern: 9 = digit, a = letter, * = alphanumeric.</summary>
    public string? InputMask { get; set; }
    /// <summary>Show an info icon next to the label.</summary>
    public bool ShowInfoIcon { get; set; }
    /// <summary>Info message shown in the info icon's tooltip.</summary>
    public string? InfoText { get; set; }
    public int ColumnSpan { get; set; } = 6;
    public int SortOrder { get; set; }
}

public sealed class DynamicFormListItemDto
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

public sealed class DynamicFormDetailDto
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
    public List<DynamicFormFieldDto> Fields { get; set; } = new();
}

/// <summary>Create or fully update a form (fields are replaced wholesale).</summary>
public sealed class SaveDynamicFormRequest
{
    public string FormKey { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsActive { get; set; } = true;
    public bool IsMultiStep { get; set; }
    public List<DynamicFormFieldDto> Fields { get; set; } = new();
}

/// <summary>One submitted entry's values: field key -> submitted value.
/// JsonElement keeps every type exact (string, boolean, number, array of
/// selections, array of grid rows) instead of flattening to text.</summary>
public sealed class SubmitDynamicFormRequest
{
    public Dictionary<string, JsonElement> Values { get; set; } = new();
}

/// <summary>One uploaded file that arrived with a submission. The content
/// stream is copied to disk by the service during the same call.</summary>
public sealed class SubmissionFileUpload
{
    public string FieldKey { get; set; } = string.Empty;
    public string FileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public Stream Content { get; set; } = Stream.Null;
}

/// <summary>One row of a form's Entries list.</summary>
public sealed class DynamicFormSubmissionListItemDto
{
    public int SubmissionId { get; set; }
    public int FormId { get; set; }
    public int? SubmittedBy { get; set; }
    public string? SubmittedByName { get; set; }
    public DateTime SubmittedAt { get; set; }
    public int ValueCount { get; set; }
}

/// <summary>One entry in full: header plus every answered field's value.</summary>
public sealed class DynamicFormSubmissionDetailDto
{
    public int SubmissionId { get; set; }
    public int FormId { get; set; }
    public int? SubmittedBy { get; set; }
    public string? SubmittedByName { get; set; }
    public DateTime SubmittedAt { get; set; }
    public Dictionary<string, JsonElement> Values { get; set; } = new();
}

public static class DynamicFormFieldTypes
{
    public static readonly string[] All =
    {
        "text", "email", "number", "password", "textarea",
        "select", "multiselect", "radio", "checkboxGroup", "checkbox",
        "date", "time", "datetime", "file", "heading", "paragraph",
        "section", "button", "hidden", "grid", "lookup", "link"
    };

    public static bool HasOptions(string fieldType) =>
        fieldType is "select" or "multiselect" or "radio" or "checkboxGroup";

    /// <summary>Field types a custom regex can be applied to.</summary>
    public static bool SupportsRegex(string fieldType) =>
        fieldType is "text" or "email" or "password" or "textarea";

    /// <summary>Display-only fields: never collected, never required-validated.</summary>
    public static bool IsStatic(string fieldType) =>
        fieldType is "heading" or "paragraph" or "section" or "button" or "link";

    public static readonly string[] GridColumnTypes = { "text", "number", "date", "select" };
}
