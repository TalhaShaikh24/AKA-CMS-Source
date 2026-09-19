using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

/// <summary>
/// Session Management Module — awareness/outreach sessions per
/// Technical Proposal v1 Phase 1 ("Awareness Session Recording")
/// with attendance capture.
/// </summary>
public interface IAwarenessSessionService
{
    Task<AwarenessSessionDetailDto> CreateAsync(
        CreateAwarenessSessionRequest request, int performedBy, string ipAddress);
    Task<AwarenessSessionDetailDto> GetByIdAsync(int sessionId);
    Task<IReadOnlyList<AwarenessSessionDto>> GetListAsync(
        string? facilityCode, DateTime? fromDate, DateTime? toDate, int top);
    Task<AwarenessSessionDetailDto> UpdateAsync(
        int sessionId, UpdateAwarenessSessionRequest request, int performedBy, string ipAddress);
    Task<RegisterSessionParticipantResponse> RegisterParticipantAsync(
        int sessionId, RegisterSessionParticipantRequest request, int performedBy, string ipAddress);
}
