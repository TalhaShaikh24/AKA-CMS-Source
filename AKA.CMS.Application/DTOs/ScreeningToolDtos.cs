namespace AKA.CMS.Application.DTOs;

public sealed record ScreeningToolQuestionDefDto(
    int QuestionId,
    string QuestionText,
    int SortOrder,
    string OptionsJson);

/* For GET /active — tools with embedded questions JSON */
public sealed class ScreeningToolActiveDto
{
    public string ToolCode { get; set; } = "";
    public string ToolName { get; set; } = "";
    public string? Description { get; set; }
    public int SortOrder { get; set; }
    public string? QuestionsJson { get; set; }
}

/* For admin list — class (not record) for Dapper mapping flexibility */
public sealed class ScreeningToolDefDto
{
    public string ToolCode { get; set; } = "";
    public string ToolName { get; set; } = "";
    public string? Description { get; set; }
    public int ItemCount { get; set; }
    public bool IsActive { get; set; }
    public int SortOrder { get; set; }
    public int QuestionCount { get; set; }
    public string? QuestionsJson { get; set; }
}

public sealed record ScreeningToolQuestionInput(
    string Text,
    object Options);

public sealed record CreateScreeningToolRequest(
    string ToolCode,
    string ToolName,
    string? Description,
    int ItemCount,
    int MaxItemScore,
    int SortOrder,
    List<ScreeningToolQuestionInput>? Questions);

public sealed record UpdateScreeningToolRequest(
    string ToolName,
    string? Description,
    bool IsActive,
    int SortOrder,
    List<ScreeningToolQuestionInput>? Questions);
