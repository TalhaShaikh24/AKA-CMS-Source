using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CreateUserRequestValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserRequestValidator()
    {
        RuleFor(x => x.Username).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Password).NotEmpty().MinimumLength(8).MaximumLength(200);
        RuleFor(x => x.Email).MaximumLength(255).EmailAddress().When(x => x.Email is not null);
        RuleForEach(x => x.RoleIds).GreaterThan(0).When(x => x.RoleIds is not null);
    }
}
