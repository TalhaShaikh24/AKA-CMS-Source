using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class SubmitScreeningRequestValidator : AbstractValidator<SubmitScreeningRequest>
{
    public SubmitScreeningRequestValidator()
    {
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.ToolCode).NotEmpty().MaximumLength(20);
        RuleFor(x => x.ItemScores)
            .NotEmpty()
            .WithMessage("At least one item score is required.");
        RuleForEach(x => x.ItemScores)
            .InclusiveBetween(0, 6)
            .WithMessage("Each item score must be between 0 and 6. " +
                "Per-tool item ranges (e.g. SBQ-R 1-4/1-5/1-3/0-6, C-SSRS 0-1) " +
                "are enforced server-side by the screening stored procedure.");
        RuleFor(x => x.ItemScores.Count)
            .LessThanOrEqualTo(30)
            .WithMessage("Too many item scores.");
    }
}
