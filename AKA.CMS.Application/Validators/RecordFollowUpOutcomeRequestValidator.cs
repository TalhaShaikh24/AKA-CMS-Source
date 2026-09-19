using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class RecordFollowUpOutcomeRequestValidator : AbstractValidator<RecordFollowUpOutcomeRequest>
{
    public RecordFollowUpOutcomeRequestValidator()
    {
        RuleFor(x => x.Outcome)
            .Must(o => o is "COMPLETED" or "MISSED" or "CANCELLED")
            .WithMessage("Outcome must be COMPLETED, MISSED or CANCELLED.");
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}
