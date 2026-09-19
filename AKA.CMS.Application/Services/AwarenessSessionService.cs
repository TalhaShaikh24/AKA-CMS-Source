using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class AwarenessSessionService(
    IAwarenessSessionRepository sessionRepository,
    ISessionParticipantRepository participantRepository,
    IValidator<CreateAwarenessSessionRequest> createValidator,
    IValidator<UpdateAwarenessSessionRequest> updateValidator,
    IValidator<RegisterSessionParticipantRequest> participantValidator) : IAwarenessSessionService
{
    public async Task<AwarenessSessionDetailDto> CreateAsync(
        CreateAwarenessSessionRequest request, int performedBy, string ipAddress)
    {
        await createValidator.ValidateAndThrowAsync(request);

        var (sessionId, _) = await sessionRepository.CreateAsync(
            request.Title, request.FacilityCode, request.SessionDate, request.ConductedBy,
            request.Topic, request.TargetGroup, request.Venue,
            request.MaleCount, request.FemaleCount, request.OtherCount, request.Notes,
            performedBy, ipAddress);

        return await GetByIdAsync(sessionId);
    }

    public async Task<AwarenessSessionDetailDto> GetByIdAsync(int sessionId)
    {
        var session = await sessionRepository.GetByIdAsync(sessionId)
            ?? throw new NotFoundException($"Awareness session {sessionId} not found.");

        var participants = await participantRepository.GetListAsync(sessionId);
        return new AwarenessSessionDetailDto(
            session.ToDto(),
            participants.Select(p => p.ToDto()).ToList());
    }

    public async Task<IReadOnlyList<AwarenessSessionDto>> GetListAsync(
        string? facilityCode, DateTime? fromDate, DateTime? toDate, int top)
    {
        var sessions = await sessionRepository.GetListAsync(facilityCode, fromDate, toDate, top);
        return sessions.Select(s => s.ToDto()).ToList();
    }

    public async Task<AwarenessSessionDetailDto> UpdateAsync(
        int sessionId, UpdateAwarenessSessionRequest request, int performedBy, string ipAddress)
    {
        await updateValidator.ValidateAndThrowAsync(request);

        await sessionRepository.UpdateAsync(
            sessionId, request.Title, request.FacilityCode, request.SessionDate,
            request.Topic, request.TargetGroup, request.Venue,
            request.MaleCount, request.FemaleCount, request.OtherCount, request.Notes,
            request.RowVersion, performedBy, ipAddress);

        return await GetByIdAsync(sessionId);
    }

    public async Task<RegisterSessionParticipantResponse> RegisterParticipantAsync(
        int sessionId, RegisterSessionParticipantRequest request, int performedBy, string ipAddress)
    {
        await participantValidator.ValidateAndThrowAsync(request);

        var (participantId, wasNew) = await participantRepository.RegisterAsync(
            sessionId, request.CommunityMemberId, request.ParticipantName,
            request.Attended, request.ConsentedToScreening, performedBy, ipAddress);

        var participants = await participantRepository.GetListAsync(sessionId);
        var participant = participants.First(p => p.ParticipantId == participantId);

        return new RegisterSessionParticipantResponse(participant.ToDto(), wasNew);
    }
}
