using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class ApplyTransitionRequestValidator : AbstractValidator<ApplyTransitionRequest>
{
    public ApplyTransitionRequestValidator()
    {
        RuleFor(x => x.Action).NotEmpty().MaximumLength(50);
        RuleFor(x => x.Comment).MaximumLength(1000);
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}
