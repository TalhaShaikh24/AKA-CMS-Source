using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IScreeningToolService
{
    Task<IReadOnlyList<ScreeningToolActiveDto>> GetActiveAsync();
    Task<IReadOnlyList<ScreeningToolDefDto>> GetAllAsync();
    Task<ScreeningToolDefDto> GetByIdAsync(string toolCode);
    Task CreateAsync(CreateScreeningToolRequest request, int performedBy);
    Task UpdateAsync(string toolCode, UpdateScreeningToolRequest request, int performedBy);
}
