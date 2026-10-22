using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IDynamicFormRepository
{
    Task<IReadOnlyList<DynamicFormListItemDto>> GetAllAsync();
    Task<DynamicFormDetailDto?> GetByIdAsync(int formId);
    Task<int> SaveAsync(int formId, SaveDynamicFormRequest request, int performedBy);
    Task DeleteAsync(int formId, int performedBy);
}

public interface IDynamicFormService
{
    Task<IReadOnlyList<DynamicFormListItemDto>> GetAllAsync();
    Task<DynamicFormDetailDto> GetByIdAsync(int formId);
    Task<DynamicFormDetailDto> CreateAsync(SaveDynamicFormRequest request, int performedBy);
    Task<DynamicFormDetailDto> UpdateAsync(int formId, SaveDynamicFormRequest request, int performedBy);
    Task DeleteAsync(int formId, int performedBy);
    Task<IReadOnlyList<DynamicFormFieldOptionDto>> GetLookupOptionsAsync(int formId, string fieldKey);
}
