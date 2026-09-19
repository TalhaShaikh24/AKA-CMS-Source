using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class AssignQueueRequestValidator : AbstractValidator<AssignQueueRequest>
{
    public AssignQueueRequestValidator()
    {
        RuleFor(x => x.AssignedToUserId).GreaterThan(0);
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}
