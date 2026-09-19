using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class TriggerCrisisEventRequestValidator : AbstractValidator<TriggerCrisisEventRequest>
{
    private static readonly string[] Severities = ["CRITICAL", "HIGH", "MODERATE"];
    private static readonly string[] Sources = ["HELPLINE_CALL", "SCREENING_SEVERE", "MANUAL"];

    public TriggerCrisisEventRequestValidator()
    {
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.CrisisTypeCode)
            .NotEmpty()
            .MaximumLength(10);
        RuleFor(x => x.Severity)
            .NotEmpty()
            .Must(s => Severities.Contains(s.ToUpperInvariant()))
            .WithMessage("Severity must be CRITICAL, HIGH or MODERATE.");
        RuleFor(x => x.TriggerSource)
            .NotEmpty()
            .Must(s => Sources.Contains(s.ToUpperInvariant()))
            .WithMessage("TriggerSource must be HELPLINE_CALL, SCREENING_SEVERE or MANUAL.");
        RuleFor(x => x.Notes).MaximumLength(4000);
    }
}
