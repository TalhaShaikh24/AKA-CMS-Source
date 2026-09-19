using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class ScheduleFollowUpRequestValidator : AbstractValidator<ScheduleFollowUpRequest>
{
    public ScheduleFollowUpRequestValidator()
    {
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.ScheduledDate).NotEmpty();
        RuleFor(x => x.FollowUpType)
            .Must(t => t is "SCHEDULED" or "QUARTERLY_RESCREEN" or "RE_ENGAGEMENT")
            .WithMessage("FollowUpType must be SCHEDULED, QUARTERLY_RESCREEN or RE_ENGAGEMENT.");
    }
}
