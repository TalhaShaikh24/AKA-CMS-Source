using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class RouteCaseRequestValidator : AbstractValidator<RouteCaseRequest>
{
    public RouteCaseRequestValidator()
    {
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.RiskCategory)
            .Must(c => c is null || new[] { "HIGH", "MODERATE", "LOW" }.Contains(c.ToUpperInvariant()))
            .WithMessage("RiskCategory must be HIGH, MODERATE or LOW when provided.");
    }
}
