using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CreateCaseRequestValidator : AbstractValidator<CreateCaseRequest>
{
    private static readonly string[] SourceTypes =
    [
        "Community", "School", "HealthFacility", "Helpline",
        "AwarenessSession", "Screening", "WalkIn", "Referral"
    ];
    private static readonly string[] PriorityLevels = ["Low", "Moderate", "High"];

    public CreateCaseRequestValidator()
    {
        RuleFor(x => x.CommunityMemberId).GreaterThan(0);
        RuleFor(x => x.SourceType).NotEmpty().Must(s => SourceTypes.Contains(s))
            .WithMessage("SourceType must be one of: Community, School, HealthFacility, Helpline, AwarenessSession, Screening, WalkIn, Referral.");
        RuleFor(x => x.PriorityLevel).Must(p => p == null || PriorityLevels.Contains(p))
            .WithMessage("PriorityLevel must be one of: Low, Moderate, High.");
        RuleFor(x => x.Notes).MaximumLength(2000);
    }
}
