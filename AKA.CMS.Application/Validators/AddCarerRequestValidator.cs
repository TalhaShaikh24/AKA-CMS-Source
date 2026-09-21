using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class AddCarerRequestValidator : AbstractValidator<AddCarerRequest>
{
    public AddCarerRequestValidator()
    {
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.FullName).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Relationship).MaximumLength(100).When(x => x.Relationship != null);
        RuleFor(x => x.Phone).MaximumLength(30).When(x => x.Phone != null);
    }
}
