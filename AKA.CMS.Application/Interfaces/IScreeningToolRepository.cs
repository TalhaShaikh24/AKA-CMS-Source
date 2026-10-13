using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IScreeningToolRepository
{
    Task<IReadOnlyList<ScreeningToolActiveDto>> GetActiveAsync();
    Task<IReadOnlyList<ScreeningToolDefDto>> GetAllAsync();
    Task<ScreeningToolDefDto?> GetByIdAsync(string toolCode);
    Task CreateAsync(CreateScreeningToolRequest request, string questionsJson, int performedBy);
    Task UpdateAsync(string toolCode, UpdateScreeningToolRequest request, string? questionsJson, int performedBy);
}
