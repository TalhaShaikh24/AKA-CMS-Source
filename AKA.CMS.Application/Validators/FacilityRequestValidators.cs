using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CreateFacilityRequestValidator : AbstractValidator<CreateFacilityRequest>
{
    public CreateFacilityRequestValidator()
    {
        RuleFor(x => x.FacilityCode).NotEmpty().MaximumLength(20);
        RuleFor(x => x.FacilityName).NotEmpty().MaximumLength(200);
        RuleFor(x => x.FacilityType).MaximumLength(50);
        RuleFor(x => x.Region).MaximumLength(100);
        RuleFor(x => x.Address).MaximumLength(500);
        RuleFor(x => x.Phone).MaximumLength(20);
    }
}

public sealed class UpdateFacilityRequestValidator : AbstractValidator<UpdateFacilityRequest>
{
    public UpdateFacilityRequestValidator()
    {
        RuleFor(x => x.FacilityName).NotEmpty().MaximumLength(200);
        RuleFor(x => x.FacilityType).MaximumLength(50);
        RuleFor(x => x.Region).MaximumLength(100);
        RuleFor(x => x.Address).MaximumLength(500);
        RuleFor(x => x.Phone).MaximumLength(20);
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}
