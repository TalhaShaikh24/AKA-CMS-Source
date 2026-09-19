using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class UpsertFacilityMrBlockRequestValidator : AbstractValidator<UpsertFacilityMrBlockRequest>
{
    public UpsertFacilityMrBlockRequestValidator()
    {
        RuleFor(x => x.UnitCode).GreaterThan(0);
        RuleFor(x => x.MrPrefix).NotEmpty().MaximumLength(10);
        RuleFor(x => x.BlockStart).GreaterThanOrEqualTo(0);
        RuleFor(x => x.BlockEnd).GreaterThanOrEqualTo(x => x.BlockStart);
    }
}
