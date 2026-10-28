using System.Text.Json;
using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IDynamicFormRepository
{
    Task<IReadOnlyList<DynamicFormListItemDto>> GetAllAsync();
    Task<DynamicFormDetailDto?> GetByIdAsync(int formId);
    Task<int> SaveAsync(int formId, SaveDynamicFormRequest request, int performedBy);
    Task DeleteAsync(int formId, int performedBy);
    Task<int> SubmitAsync(int formId, int? submittedBy, IReadOnlyList<(string FieldKey, string ValueJson)> values);
    Task<IReadOnlyList<DynamicFormSubmissionListItemDto>> GetSubmissionsByFormAsync(int formId);
    Task<DynamicFormSubmissionDetailDto?> GetSubmissionByIdAsync(int submissionId);
    Task DeleteSubmissionAsync(int submissionId, int performedBy);
    Task<IReadOnlyList<string>> GetFieldValuesAsync(int formId, string fieldKey);
}

public interface IDynamicFormService
{
    Task<IReadOnlyList<DynamicFormListItemDto>> GetAllAsync();
    Task<DynamicFormDetailDto> GetByIdAsync(int formId);
    Task<DynamicFormDetailDto> CreateAsync(SaveDynamicFormRequest request, int performedBy);
    Task<DynamicFormDetailDto> UpdateAsync(int formId, SaveDynamicFormRequest request, int performedBy);
    Task DeleteAsync(int formId, int performedBy);
    Task<IReadOnlyList<DynamicFormFieldOptionDto>> GetLookupOptionsAsync(int formId, string fieldKey);
    Task<DynamicFormSubmissionDetailDto> SubmitAsync(
        int formId, Dictionary<string, JsonElement> values,
        IReadOnlyList<SubmissionFileUpload> files, int submittedBy);
    Task<IReadOnlyList<DynamicFormSubmissionListItemDto>> GetSubmissionsAsync(int formId);
    Task<DynamicFormSubmissionDetailDto> GetSubmissionAsync(int submissionId);
    Task DeleteSubmissionAsync(int submissionId, int performedBy);
    Task<(string FileName, string ContentType, string StoragePath)> GetSubmissionFileAsync(int submissionId, string fieldKey);
}
