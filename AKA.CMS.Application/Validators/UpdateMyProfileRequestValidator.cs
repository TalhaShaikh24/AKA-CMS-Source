using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class UpdateMyProfileRequestValidator : AbstractValidator<UpdateMyProfileRequest>
{
    public UpdateMyProfileRequestValidator()
    {
        RuleFor(x => x.NewPassword).MinimumLength(8).MaximumLength(200).When(x => x.NewPassword is not null);
        RuleFor(x => x.Email).MaximumLength(255).EmailAddress().When(x => x.Email is not null);
    }
}
