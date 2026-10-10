using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class UpdateScreeningRequestValidator : AbstractValidator<UpdateScreeningRequest>
{
    public UpdateScreeningRequestValidator()
    {
        RuleFor(x => x.ItemScores)
            .NotEmpty()
            .WithMessage("At least one item score is required.");
        RuleForEach(x => x.ItemScores)
            .InclusiveBetween(0, 6)
            .WithMessage("Each item score must be between 0 and 6.");
        RuleFor(x => x.ItemScores.Count)
            .LessThanOrEqualTo(30)
            .WithMessage("Too many item scores.");
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}
