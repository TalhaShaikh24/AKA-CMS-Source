using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Interfaces;

public interface IPatientRepository
{
    Task<int> CreateCommunityMemberAsync(CommunityMember member, int performedBy, string ipAddress);
    Task<CommunityMember?> GetCommunityMemberByIdAsync(int memberId);
    Task<IReadOnlyList<PatientSearchHit>> SearchAsync(string? searchTerm);
    Task<(HisMrMapping Mapping, bool WasCreated)> ResolveOrCreateMappingAsync(
        string? mrNo, int unitCode, int? communityMemberId, int performedBy, string ipAddress);
    Task<HisMrMapping> RemapToRealMrAsync(
        int mappingId, string realMrNo, byte[] rowVersion, int performedBy, string ipAddress);
    Task<IReadOnlyList<FacilityMrBlock>> GetFacilityMrBlocksAsync();
    Task UpsertFacilityMrBlockAsync(
        int unitCode, string mrPrefix, int blockStart, int blockEnd, bool isActive, int performedBy);
}
