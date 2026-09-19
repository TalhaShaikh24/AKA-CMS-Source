using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using AKA.CMS.Domain.Entities;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class PatientService(
    IPatientRepository patientRepository,
    IValidator<CreateCommunityMemberRequest> createValidator,
    IValidator<ResolveIdentityRequest> resolveValidator,
    IValidator<RemapMrRequest> remapValidator,
    IValidator<UpsertFacilityMrBlockRequest> mrBlockValidator) : IPatientService
{
    public async Task<IReadOnlyList<PatientSearchResultDto>> SearchAsync(string? searchTerm)
    {
        var hits = await patientRepository.SearchAsync(searchTerm);
        return hits.Select(h => h.ToDto()).ToList();
    }

    public async Task<CommunityMemberDto> RegisterCommunityMemberAsync(
        CreateCommunityMemberRequest request, int performedBy, string ipAddress)
    {
        await createValidator.ValidateAndThrowAsync(request);

        var memberId = await patientRepository.CreateCommunityMemberAsync(
            new CommunityMember
            {
                MrNo = request.MrNo,
                FullName = request.FullName,
                FatherName = request.FatherName,
                Gender = request.Gender,
                DateOfBirth = request.DateOfBirth,
                Cnic = request.Cnic,
                Phone = request.Phone,
                Address = request.Address,
                UnionCouncilCode = request.UnionCouncilCode,
                VillageCode = request.VillageCode,
                IsActive = true
            },
            performedBy,
            ipAddress);

        var member = await patientRepository.GetCommunityMemberByIdAsync(memberId)
            ?? throw new NotFoundException($"Community member {memberId} not found.");
        return member.ToDto();
    }

    public async Task<ResolveIdentityResponse> ResolveIdentityAsync(
        ResolveIdentityRequest request, int performedBy, string ipAddress)
    {
        await resolveValidator.ValidateAndThrowAsync(request);

        int? memberId = request.CommunityMemberId;
        if (memberId is null && !string.IsNullOrWhiteSpace(request.FullName))
        {
            memberId = await patientRepository.CreateCommunityMemberAsync(
                new CommunityMember
                {
                    FullName = request.FullName,
                    Gender = request.Gender,
                    Phone = request.Phone,
                    Cnic = request.Cnic,
                    IsActive = true
                },
                performedBy,
                ipAddress);
        }

        var (mapping, wasCreated) = await patientRepository.ResolveOrCreateMappingAsync(
            request.MrNo, request.UnitCode, memberId, performedBy, ipAddress);

        return mapping.ToResolveResponse(wasCreated);
    }

    public async Task<ResolveIdentityResponse> RemapMrAsync(
        RemapMrRequest request, int performedBy, string ipAddress)
    {
        await remapValidator.ValidateAndThrowAsync(request);

        var mapping = await patientRepository.RemapToRealMrAsync(
            request.MappingId, request.RealMrNo, request.RowVersion, performedBy, ipAddress);

        return mapping.ToResolveResponse(wasCreated: false);
    }

    public async Task<IReadOnlyList<FacilityMrBlockDto>> GetMrBlocksAsync()
    {
        var blocks = await patientRepository.GetFacilityMrBlocksAsync();
        return blocks.Select(b => b.ToDto()).ToList();
    }

    public async Task UpsertMrBlockAsync(UpsertFacilityMrBlockRequest request, int performedBy)
    {
        await mrBlockValidator.ValidateAndThrowAsync(request);
        await patientRepository.UpsertFacilityMrBlockAsync(
            request.UnitCode, request.MrPrefix, request.BlockStart, request.BlockEnd, request.IsActive, performedBy);
    }
}
