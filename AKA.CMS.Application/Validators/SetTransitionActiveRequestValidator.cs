using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class SetTransitionActiveRequestValidator
    : AbstractValidator<SetTransitionActiveRequest>
{
    public SetTransitionActiveRequestValidator()
    {
        RuleFor(x => x.RowVersion).NotEmpty().Must(rv => rv.Length == 8)
            .WithMessage("RowVersion must be 8 bytes.");
    }
}
