using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CreateCommunityMemberRequestValidator : AbstractValidator<CreateCommunityMemberRequest>
{
    public CreateCommunityMemberRequestValidator()
    {
        RuleFor(x => x.FullName).NotEmpty().MaximumLength(200);
        RuleFor(x => x.FatherName).MaximumLength(200);
        RuleFor(x => x.Gender).MaximumLength(10);
        RuleFor(x => x.Cnic).MaximumLength(15);
        RuleFor(x => x.Phone).MaximumLength(20);
        RuleFor(x => x.Address).MaximumLength(500);
        RuleFor(x => x.MrNo).MaximumLength(20);
    }
}
