using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using AKA.CMS.Domain.Entities;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CreateRegionRequestValidator : AbstractValidator<CreateRegionRequest>
{
    public CreateRegionRequestValidator()
    {
        RuleFor(x => x.RegionName).NotEmpty().MaximumLength(100);
    }
}

public sealed class UpdateRegionRequestValidator : AbstractValidator<UpdateRegionRequest>
{
    public UpdateRegionRequestValidator()
    {
        RuleFor(x => x.RegionName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}

public sealed class CreateLocalCouncilRequestValidator : AbstractValidator<CreateLocalCouncilRequest>
{
    public CreateLocalCouncilRequestValidator()
    {
        RuleFor(x => x.CouncilName).NotEmpty().MaximumLength(100);
    }
}

public sealed class UpdateLocalCouncilRequestValidator : AbstractValidator<UpdateLocalCouncilRequest>
{
    public UpdateLocalCouncilRequestValidator()
    {
        RuleFor(x => x.CouncilName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}

public sealed class CreateVillageRequestValidator : AbstractValidator<CreateVillageRequest>
{
    public CreateVillageRequestValidator()
    {
        RuleFor(x => x.VillageName).NotEmpty().MaximumLength(100);
    }
}

public sealed class UpdateVillageRequestValidator : AbstractValidator<UpdateVillageRequest>
{
    public UpdateVillageRequestValidator()
    {
        RuleFor(x => x.VillageName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}
