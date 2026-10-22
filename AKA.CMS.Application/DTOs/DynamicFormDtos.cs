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

public static class DynamicFormFieldTypes
{
    public static readonly string[] All =
    {
        "text", "email", "number", "password", "textarea",
        "select", "multiselect", "radio", "checkboxGroup", "checkbox",
        "date", "time", "datetime", "file", "heading", "paragraph",
        "section", "button", "hidden", "grid", "lookup"
    };

    public static bool HasOptions(string fieldType) =>
        fieldType is "select" or "multiselect" or "radio" or "checkboxGroup";

    /// <summary>Field types a custom regex can be applied to.</summary>
    public static bool SupportsRegex(string fieldType) =>
        fieldType is "text" or "email" or "password" or "textarea";

    /// <summary>Display-only fields: never collected, never required-validated.</summary>
    public static bool IsStatic(string fieldType) =>
        fieldType is "heading" or "paragraph" or "section" or "button";

    public static readonly string[] GridColumnTypes = { "text", "number", "date", "select" };
}
