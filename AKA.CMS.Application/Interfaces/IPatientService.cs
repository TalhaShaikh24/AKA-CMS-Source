using AKA.CMS.Application.DTOs;

namespace AKA.CMS.Application.Interfaces;

public interface IPatientService
{
    Task<IReadOnlyList<PatientSearchResultDto>> SearchAsync(string? searchTerm);
    Task<CommunityMemberDto> GetCommunityMemberByIdAsync(int memberId);
    Task<CommunityMemberDto> RegisterCommunityMemberAsync(
        CreateCommunityMemberRequest request, int performedBy, string ipAddress);
    Task<ResolveIdentityResponse> ResolveIdentityAsync(
        ResolveIdentityRequest request, int performedBy, string ipAddress);
    Task<ResolveIdentityResponse> RemapMrAsync(
        RemapMrRequest request, int performedBy, string ipAddress);
    Task<IReadOnlyList<FacilityMrBlockDto>> GetMrBlocksAsync();
    Task UpsertMrBlockAsync(UpsertFacilityMrBlockRequest request, int performedBy);
}
