using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CreateCarePlanRequestValidator : AbstractValidator<CreateCarePlanRequest>
{
    public CreateCarePlanRequestValidator()
    {
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.RiskCategory)
            .NotEmpty()
            .Must(c => new[] { "HIGH", "MODERATE", "LOW" }.Contains(c.ToUpperInvariant()))
            .WithMessage("RiskCategory must be HIGH, MODERATE or LOW.");
        RuleFor(x => x.Title).MaximumLength(200);
    }
}
