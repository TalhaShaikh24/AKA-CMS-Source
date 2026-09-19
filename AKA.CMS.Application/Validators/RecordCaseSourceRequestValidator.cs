using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

/// <summary>
/// Source codes come from CMS_CaseSourceTypes, which is seeded from
/// client docs (see database/01_Schema/15_CMS_AwarenessSeed.sql).
/// Keep this list in sync with the seed.
/// </summary>
public sealed class RecordCaseSourceRequestValidator : AbstractValidator<RecordCaseSourceRequest>
{
    private static readonly string[] SourceTypes =
    [
        "Community", "School", "HealthFacility", "Helpline",
        "AwarenessSession", "Screening", "WalkIn", "Referral"
    ];

    public RecordCaseSourceRequestValidator()
    {
        RuleFor(x => x.SourceType).NotEmpty()
            .Must(s => SourceTypes.Contains(s))
            .WithMessage("SourceType must be one of: " + string.Join(", ", SourceTypes) + ".");
        RuleFor(x => x.SourceReferenceId).GreaterThan(0)
            .When(x => x.SourceReferenceId.HasValue);
    }
}
