using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CreateSafetyPlanRequestValidator : AbstractValidator<CreateSafetyPlanRequest>
{
    public CreateSafetyPlanRequestValidator()
    {
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.WarningSigns)
            .NotEmpty()
            .MaximumLength(4000);
        RuleFor(x => x.CopingStrategies)
            .NotEmpty()
            .MaximumLength(4000);
        RuleFor(x => x.SupportContactsJson).MaximumLength(4000);
    }
}
