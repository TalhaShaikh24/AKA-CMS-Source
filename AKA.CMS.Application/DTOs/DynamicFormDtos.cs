namespace AKA.CMS.Application.DTOs;

/// <summary>One field option for select / multiselect / radio / checkbox-group fields.</summary>
public sealed class DynamicFormFieldOptionDto
{
    public string Value { get; set; } = string.Empty;
    public string Label { get; set; } = string.Empty;
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
    public List<DynamicFormFieldDto> Fields { get; set; } = new();
}

public static class DynamicFormFieldTypes
{
    public static readonly string[] All =
    {
        "text", "email", "number", "password", "textarea",
        "select", "multiselect", "radio", "checkboxGroup", "checkbox",
        "date", "time", "datetime", "file", "heading", "paragraph"
    };

    public static bool HasOptions(string fieldType) =>
        fieldType is "select" or "multiselect" or "radio" or "checkboxGroup";
}
