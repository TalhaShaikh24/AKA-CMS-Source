using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CreateUserRequestValidator : AbstractValidator<CreateUserRequest>
{
    public CreateUserRequestValidator()
    {
        RuleFor(x => x.Username).NotEmpty().MaximumLength(100);
        RuleFor(x => x.UserType)
            .Must(t => t is null or "System" or "AD")
            .WithMessage("UserType must be 'System' or 'AD'.");
        // Until real AD (LDAP) login is connected, AD users also get a local
        // password so they can sign in. Once AD config arrives, Type='AD'
        // users will be verified against the directory instead.
        RuleFor(x => x.Password).NotEmpty().MinimumLength(8).MaximumLength(200);
        RuleFor(x => x.Email).MaximumLength(255).EmailAddress().When(x => x.Email is not null);
        RuleForEach(x => x.RoleIds).GreaterThan(0).When(x => x.RoleIds is not null);
    }
}
