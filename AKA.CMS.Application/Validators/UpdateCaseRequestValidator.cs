using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class UpdateCaseRequestValidator : AbstractValidator<UpdateCaseRequest>
{
    private static readonly string[] PriorityLevels = ["Low", "Moderate", "High"];

    public UpdateCaseRequestValidator()
    {
        RuleFor(x => x.PriorityLevel).Must(p => p == null || PriorityLevels.Contains(p))
            .WithMessage("PriorityLevel must be one of: Low, Moderate, High.");
        RuleFor(x => x.Notes).MaximumLength(2000);
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}
