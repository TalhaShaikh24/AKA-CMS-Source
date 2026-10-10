using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IReferralService
{
    Task<ReferralDto> CreateAsync(CreateReferralRequest request, int performedBy, string ipAddress);
    Task<UpdateReferralStatusResponse> UpdateStatusAsync(
        int referralId, UpdateReferralStatusRequest request,
        Func<string, bool> hasPermission, int performedBy, string ipAddress);
    Task<IReadOnlyList<ReferralDto>> GetByCaseAsync(int caseId);
    Task<IReadOnlyList<ReferralDto>> GetAllAsync(int top = 100);
}
