using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class SupervisionService(
    ISupervisionRepository supervisionRepository,
    IValidator<LogSupervisionRequest> logValidator) : ISupervisionService
{
    public async Task<SupervisionLogDto> LogReviewAsync(
        LogSupervisionRequest request, int performedBy, string ipAddress)
    {
        await logValidator.ValidateAndThrowAsync(request);

        var logId = await supervisionRepository.LogReviewAsync(
            request.CaseId, request.SupervisorUserId, request.ReviewDate,
            request.Findings, request.ActionItems, request.Rating,
            performedBy, ipAddress);

        var log = (await supervisionRepository.GetByCaseAsync(request.CaseId))
            .First(l => l.SupervisionLogId == logId);
        return log.ToDto();
    }

    public async Task<IReadOnlyList<SupervisionLogDto>> GetByCaseAsync(int caseId)
    {
        var logs = await supervisionRepository.GetByCaseAsync(caseId);
        return logs.Select(l => l.ToDto()).ToList();
    }
}
