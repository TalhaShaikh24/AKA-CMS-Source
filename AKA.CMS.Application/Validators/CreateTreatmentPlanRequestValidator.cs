using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CreateTreatmentPlanRequestValidator : AbstractValidator<CreateTreatmentPlanRequest>
{
    public CreateTreatmentPlanRequestValidator()
    {
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.PlanTrack).Must(t => t is "PSYCH" or "PHARM")
            .WithMessage("PlanTrack must be PSYCH or PHARM.");
        RuleFor(x => x.Title).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Goals).MaximumLength(2000);
        RuleFor(x => x.PlannedInterventions).MaximumLength(2000);
        RuleFor(x => x.StartDate).NotEmpty();
        RuleFor(x => x.PlannedEndDate)
            .GreaterThanOrEqualTo(x => x.StartDate)
            .When(x => x.PlannedEndDate.HasValue);
    }
}
