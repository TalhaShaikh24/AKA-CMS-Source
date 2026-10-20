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
        // Local password is required only for system users; AD users
        // authenticate against Active Directory.
        RuleFor(x => x.Password).NotEmpty().MinimumLength(8).MaximumLength(200)
            .When(x => !string.Equals(x.UserType, "AD", StringComparison.OrdinalIgnoreCase));
        RuleFor(x => x.Email).MaximumLength(255).EmailAddress().When(x => x.Email is not null);
        RuleForEach(x => x.RoleIds).GreaterThan(0).When(x => x.RoleIds is not null);
    }
}
