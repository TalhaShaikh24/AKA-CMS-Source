using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class AssignCaseRequestValidator : AbstractValidator<AssignCaseRequest>
{
    public AssignCaseRequestValidator()
    {
        RuleFor(x => x.UserId).GreaterThan(0);
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}
