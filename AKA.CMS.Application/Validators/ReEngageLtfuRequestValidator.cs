using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class ReEngageLtfuRequestValidator : AbstractValidator<ReEngageLtfuRequest>
{
    public ReEngageLtfuRequestValidator()
    {
        RuleFor(x => x.ReEngagementNotes).NotEmpty().MaximumLength(2000);
    }
}
