using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class UpdateTreatmentPlanRequestValidator : AbstractValidator<UpdateTreatmentPlanRequest>
{
    public UpdateTreatmentPlanRequestValidator()
    {
        RuleFor(x => x.Title).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Goals).MaximumLength(2000);
        RuleFor(x => x.PlannedInterventions).MaximumLength(2000);
        RuleFor(x => x.Status).Must(s => s is "Active" or "Completed" or "Discontinued")
            .WithMessage("Status must be Active, Completed or Discontinued.");
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}
