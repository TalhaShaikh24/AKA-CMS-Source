using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Mapping;
using FluentValidation;

namespace AKA.CMS.Application.Services;

public sealed class CarerService(
    ICarerRepository carerRepository,
    IValidator<AddCarerRequest> addValidator,
    IValidator<UpdateCarerRequest> updateValidator) : ICarerService
{
    public async Task<CarerDto> AddAsync(
        AddCarerRequest request, int performedBy, string ipAddress)
    {
        await addValidator.ValidateAndThrowAsync(request);

        var carerId = await carerRepository.AddAsync(
            request.CaseId, request.FullName, request.Relationship, request.Phone,
            request.IsPrimary, performedBy, ipAddress);

        var carers = await carerRepository.GetByCaseAsync(request.CaseId);
        return carers.First(c => c.CarerId == carerId).ToDto();
    }

    public async Task<CarerDto> UpdateAsync(
        int carerId, int caseId, UpdateCarerRequest request,
        int performedBy, string ipAddress)
    {
        await updateValidator.ValidateAndThrowAsync(request);

        await carerRepository.UpdateAsync(
            carerId, caseId, request.FullName, request.Relationship, request.Phone,
            request.IsPrimary, request.RowVersion, performedBy, ipAddress);

        var carers = await carerRepository.GetByCaseAsync(caseId);
        return carers.First(c => c.CarerId == carerId).ToDto();
    }

    public async Task DeactivateAsync(
        int carerId, int caseId, byte[] rowVersion,
        int performedBy, string ipAddress)
    {
        if (rowVersion is null || rowVersion.Length == 0)
            throw new ScreeningValidationException("RowVersion is required.");

        await carerRepository.DeactivateAsync(
            carerId, caseId, rowVersion, performedBy, ipAddress);
    }

    public async Task<IReadOnlyList<CarerDto>> GetByCaseAsync(int caseId)
    {
        var carers = await carerRepository.GetByCaseAsync(caseId);
        return carers.Select(c => c.ToDto()).ToList();
    }
}
