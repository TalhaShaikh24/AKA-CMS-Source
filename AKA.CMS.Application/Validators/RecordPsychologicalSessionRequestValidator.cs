using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class RecordPsychologicalSessionRequestValidator : AbstractValidator<RecordPsychologicalSessionRequest>
{
    public RecordPsychologicalSessionRequestValidator()
    {
        RuleFor(x => x.PlanId).GreaterThan(0);
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.SessionDate).NotEmpty();
        RuleFor(x => x.ModalityCode).NotEmpty().MaximumLength(20);
        RuleFor(x => x.DurationMinutes).GreaterThan(0).When(x => x.DurationMinutes.HasValue);
        RuleFor(x => x.SessionNotes).MaximumLength(2000);
        RuleFor(x => x.OutcomeNotes).MaximumLength(2000);
    }
}
