using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class RemapMrRequestValidator : AbstractValidator<RemapMrRequest>
{
    public RemapMrRequestValidator()
    {
        RuleFor(x => x.MappingId).GreaterThan(0);
        RuleFor(x => x.RealMrNo).NotEmpty().MaximumLength(20);
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}
