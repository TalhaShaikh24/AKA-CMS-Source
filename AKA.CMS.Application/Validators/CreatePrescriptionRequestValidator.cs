using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CreatePrescriptionRequestValidator : AbstractValidator<CreatePrescriptionRequest>
{
    public CreatePrescriptionRequestValidator()
    {
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.PlanId).GreaterThan(0).When(x => x.PlanId.HasValue);
        RuleFor(x => x.MedicationId).GreaterThan(0);
        RuleFor(x => x.DoseText).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Frequency).NotEmpty().MaximumLength(100);
        RuleFor(x => x.DurationDays).GreaterThan(0);
        RuleFor(x => x.Instructions).MaximumLength(500);
        RuleFor(x => x.DiagnosisText).MaximumLength(500);
    }
}
