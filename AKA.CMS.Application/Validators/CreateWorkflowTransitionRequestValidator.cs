using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CreateWorkflowTransitionRequestValidator
    : AbstractValidator<CreateWorkflowTransitionRequest>
{
    public CreateWorkflowTransitionRequestValidator()
    {
        RuleFor(x => x.FromState).NotEmpty().MaximumLength(30);
        RuleFor(x => x.ActionCode).NotEmpty().MaximumLength(50);
        RuleFor(x => x.ActionName).NotEmpty().MaximumLength(100);
        RuleFor(x => x.ToState).NotEmpty().MaximumLength(30);
        RuleFor(x => x.RequiredPermissionName).MaximumLength(100)
            .When(x => x.RequiredPermissionName is not null);
        RuleFor(x => x.SortOrder).GreaterThanOrEqualTo(0);
    }
}
