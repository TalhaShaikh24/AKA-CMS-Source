using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class RequestCaseClosureRequestValidator : AbstractValidator<RequestCaseClosureRequest>
{
    public RequestCaseClosureRequestValidator()
    {
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.ClosureReason)
            .Must(r => r is "TREATMENT_COMPLETE" or "SYMPTOM_REMISSION" or "LTFU"
                       or "NO_CONSENT" or "REFERRAL_COMPLETE" or "OTHER")
            .WithMessage("ClosureReason is not a recognized value.");
    }
}
