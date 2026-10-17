using AKA.CMS.Application.DTOs;
using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IRiskAssessmentRepository
{
    Task<int> SaveAsync(CaseRiskAssessment assessment, int performedBy);
    Task<CaseRiskAssessment?> GetByCaseAsync(int caseId);
}

public interface IRiskAssessmentService
{
    Task<RiskAssessmentDto> SaveAsync(int caseId, SaveRiskAssessmentRequest request, int performedBy);
    Task<RiskAssessmentDto?> GetByCaseAsync(int caseId);
}
