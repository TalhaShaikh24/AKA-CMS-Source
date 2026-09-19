using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class DispenseMedicationRequestValidator : AbstractValidator<DispenseMedicationRequest>
{
    public DispenseMedicationRequestValidator()
    {
        RuleFor(x => x.DispensedDate).NotEmpty();
        RuleFor(x => x.Quantity).GreaterThan(0);
        RuleFor(x => x.AdherenceNotes).MaximumLength(1000);
    }
}
