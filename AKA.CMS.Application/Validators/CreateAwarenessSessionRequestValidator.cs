using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CreateAwarenessSessionRequestValidator : AbstractValidator<CreateAwarenessSessionRequest>
{
    public CreateAwarenessSessionRequestValidator()
    {
        RuleFor(x => x.Title).NotEmpty().MaximumLength(200);
        RuleFor(x => x.FacilityCode).MaximumLength(20);
        RuleFor(x => x.SessionDate).NotEmpty();
        RuleFor(x => x.Topic).MaximumLength(200);
        RuleFor(x => x.TargetGroup).MaximumLength(100);
        RuleFor(x => x.Venue).MaximumLength(200);
        RuleFor(x => x.MaleCount).GreaterThanOrEqualTo(0);
        RuleFor(x => x.FemaleCount).GreaterThanOrEqualTo(0);
        RuleFor(x => x.OtherCount).GreaterThanOrEqualTo(0);
        RuleFor(x => x.Notes).MaximumLength(2000);
    }
}
