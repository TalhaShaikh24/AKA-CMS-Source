using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CreateReferralRequestValidator : AbstractValidator<CreateReferralRequest>
{
    private static readonly string[] Targets =
        ["PSYCHOLOGIST", "PSYCHIATRIST", "PSYCHOSOCIAL", "EMERGENCY_SERVICES"];

    public CreateReferralRequestValidator()
    {
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.ReferredTo)
            .NotEmpty()
            .Must(t => Targets.Contains(t.ToUpperInvariant()))
            .WithMessage("ReferredTo must be PSYCHOLOGIST, PSYCHIATRIST, PSYCHOSOCIAL or EMERGENCY_SERVICES.");
        RuleFor(x => x.SlaDueAt)
            .GreaterThan(DateTime.UtcNow)
            .When(x => x.SlaDueAt.HasValue)
            .WithMessage("SlaDueAt must be in the future.");
        RuleFor(x => x.Notes).MaximumLength(500);
    }
}
