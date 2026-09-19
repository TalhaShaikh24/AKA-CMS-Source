using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IPsychologicalSessionService
{
    Task<PsychologicalSessionDto> RecordAsync(
        RecordPsychologicalSessionRequest request, int performedBy, string ipAddress);
    Task<IReadOnlyList<PsychologicalSessionDto>> GetByCaseAsync(int caseId);
}
