using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface ICaseCommentRepository
{
    Task<int> AddAsync(int caseId, string? commentType, string comment, int createdBy, string ipAddress);
    Task<IReadOnlyList<CaseComment>> GetByCaseAsync(int caseId);
}
