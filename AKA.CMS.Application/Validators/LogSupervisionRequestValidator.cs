using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class LogSupervisionRequestValidator : AbstractValidator<LogSupervisionRequest>
{
    public LogSupervisionRequestValidator()
    {
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.SupervisorUserId).GreaterThan(0);
        RuleFor(x => x.ReviewDate).NotEmpty();
        RuleFor(x => x.Findings).NotEmpty().MaximumLength(4000);
        RuleFor(x => x.Rating)
            .Must(r => r is null or "SATISFACTORY" or "NEEDS_IMPROVEMENT" or "UNSATISFACTORY")
            .WithMessage("Rating must be SATISFACTORY, NEEDS_IMPROVEMENT or UNSATISFACTORY.");
    }
}
