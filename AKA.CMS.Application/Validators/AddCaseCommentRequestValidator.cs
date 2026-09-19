using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class AddCaseCommentRequestValidator : AbstractValidator<AddCaseCommentRequest>
{
    public AddCaseCommentRequestValidator()
    {
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.CommentType)
            .Must(t => t is null || new[] { "NOTE", "ALERT", "HANDOVER" }.Contains(t.ToUpperInvariant()))
            .WithMessage("CommentType must be NOTE, ALERT or HANDOVER.");
        RuleFor(x => x.Comment).NotEmpty().MaximumLength(2000);
    }
}
