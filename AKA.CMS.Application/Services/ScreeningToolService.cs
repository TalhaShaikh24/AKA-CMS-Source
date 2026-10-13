using System.Text.Json;
using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;

namespace AKA.CMS.Application.Services;

public sealed class ScreeningToolService : IScreeningToolService
{
    private readonly IScreeningToolRepository _repo;

    public ScreeningToolService(IScreeningToolRepository repo)
    {
        _repo = repo;
    }

    public Task<IReadOnlyList<ScreeningToolActiveDto>> GetActiveAsync() => _repo.GetActiveAsync();

    public Task<IReadOnlyList<ScreeningToolDefDto>> GetAllAsync() => _repo.GetAllAsync();

    public async Task<ScreeningToolDefDto> GetByIdAsync(string toolCode)
    {
        var tool = await _repo.GetByIdAsync(toolCode);
        if (tool is null) throw new NotFoundException($"Screening tool '{toolCode}' not found.");
        return tool;
    }

    public async Task CreateAsync(CreateScreeningToolRequest request, int performedBy)
    {
        if (string.IsNullOrWhiteSpace(request.ToolCode)) throw new ScreeningValidationException("Tool code is required.");
        if (string.IsNullOrWhiteSpace(request.ToolName)) throw new ScreeningValidationException("Tool name is required.");
        if (request.ItemCount < 1 || request.ItemCount > 30) throw new ScreeningValidationException("Item count must be between 1 and 30.");
        var questionsJson = SerializeQuestions(request.Questions);
        await _repo.CreateAsync(request, questionsJson, performedBy);
    }

    public async Task UpdateAsync(string toolCode, UpdateScreeningToolRequest request, int performedBy)
    {
        _ = await GetByIdAsync(toolCode);
        if (string.IsNullOrWhiteSpace(request.ToolName)) throw new ScreeningValidationException("Tool name is required.");
        var questionsJson = request.Questions is null ? null : SerializeQuestions(request.Questions);
        await _repo.UpdateAsync(toolCode, request, questionsJson, performedBy);
    }

    private static string? SerializeQuestions(List<ScreeningToolQuestionInput>? questions)
    {
        if (questions is null || questions.Count == 0) return null;
        return JsonSerializer.Serialize(questions.Select(q => new { text = q.Text, options = q.Options }));
    }
}
