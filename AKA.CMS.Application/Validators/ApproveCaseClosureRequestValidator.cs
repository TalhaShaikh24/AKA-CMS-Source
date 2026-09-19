using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class ApproveCaseClosureRequestValidator : AbstractValidator<ApproveCaseClosureRequest>
{
    public ApproveCaseClosureRequestValidator()
    {
        RuleFor(x => x.RowVersion).NotEmpty();
        RuleFor(x => x.RejectionReason)
            .NotEmpty()
            .When(x => !x.Approve)
            .WithMessage("RejectionReason is required when rejecting a closure request.");
    }
}
