using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class UpdateAwarenessSessionRequestValidator : AbstractValidator<UpdateAwarenessSessionRequest>
{
    public UpdateAwarenessSessionRequestValidator()
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
        RuleFor(x => x.RowVersion).NotNull().NotEmpty()
            .WithMessage("RowVersion is required for optimistic concurrency.");
    }
}
