using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IReferralRepository
{
    Task<int> CreateAsync(int caseId, string referredTo, DateTime? slaDueAt, string? notes, int createdBy, string ipAddress);
    Task<Referral> GetByIdAsync(int referralId);
    Task<(int NewReferralId, string Status)> UpdateStatusAsync(
        int referralId, string newStatus, string? rejectionReason, byte[] rowVersion, int performedBy, string ipAddress);
    Task<IReadOnlyList<Referral>> GetByCaseAsync(int caseId);
}
