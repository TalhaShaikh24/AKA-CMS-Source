using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class LogHelplineCallRequestValidator : AbstractValidator<LogHelplineCallRequest>
{
    public LogHelplineCallRequestValidator()
    {
        RuleFor(x => x.CaseId)
            .GreaterThan(0)
            .When(x => x.CaseId.HasValue);
        RuleFor(x => x.CallerName).MaximumLength(200);
        RuleFor(x => x.CallerPhone).MaximumLength(30);
        RuleFor(x => x.CallNotes).MaximumLength(4000);
        RuleFor(x => x.Indicators).NotNull();
    }
}
