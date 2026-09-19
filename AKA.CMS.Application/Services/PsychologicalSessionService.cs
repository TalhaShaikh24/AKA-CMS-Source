using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class PsychologicalSessionService(
    IPsychologicalSessionRepository sessionRepository,
    IValidator<RecordPsychologicalSessionRequest> recordValidator) : IPsychologicalSessionService
{
    public async Task<PsychologicalSessionDto> RecordAsync(
        RecordPsychologicalSessionRequest request, int performedBy, string ipAddress)
    {
        await recordValidator.ValidateAndThrowAsync(request);

        var sessionId = await sessionRepository.RecordAsync(
            request.PlanId, request.CaseId, request.TherapistUserId, request.SessionDate,
            request.ModalityCode, request.DurationMinutes, request.SessionNotes,
            request.OutcomeNotes, request.NextSessionDate,
            performedBy, ipAddress);

        var sessions = await sessionRepository.GetByCaseAsync(request.CaseId);
        return sessions.First(s => s.SessionId == sessionId).ToDto();
    }

    public async Task<IReadOnlyList<PsychologicalSessionDto>> GetByCaseAsync(int caseId)
    {
        var sessions = await sessionRepository.GetByCaseAsync(caseId);
        return sessions.Select(s => s.ToDto()).ToList();
    }
}
