using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface ICaseCommentService
{
    Task<CaseCommentDto> AddAsync(AddCaseCommentRequest request, int performedBy, string ipAddress);
    Task<IReadOnlyList<CaseCommentDto>> GetByCaseAsync(int caseId);
}
