using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class UpdateCrisisEventStatusRequestValidator : AbstractValidator<UpdateCrisisEventStatusRequest>
{
    private static readonly string[] Statuses = ["STABILIZED", "ESCALATED", "CONTINUE_CARE"];

    public UpdateCrisisEventStatusRequestValidator()
    {
        RuleFor(x => x.NewStatus)
            .NotEmpty()
            .Must(s => Statuses.Contains(s.ToUpperInvariant()))
            .WithMessage("NewStatus must be STABILIZED, ESCALATED or CONTINUE_CARE.");
        RuleFor(x => x.RowVersion)
            .NotEmpty()
            .WithMessage("RowVersion is required for concurrency control.");
    }
}
