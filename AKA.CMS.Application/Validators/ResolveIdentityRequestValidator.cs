using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class ResolveIdentityRequestValidator : AbstractValidator<ResolveIdentityRequest>
{
    public ResolveIdentityRequestValidator()
    {
        RuleFor(x => x.UnitCode).GreaterThan(0);
        RuleFor(x => x.MrNo).MaximumLength(20);
        RuleFor(x => x.CommunityMemberId).GreaterThan(0).When(x => x.CommunityMemberId.HasValue);
        RuleFor(x => x)
            .Must(x => !string.IsNullOrWhiteSpace(x.MrNo)
                       || x.CommunityMemberId.HasValue
                       || !string.IsNullOrWhiteSpace(x.FullName))
            .WithMessage("Provide an MR number, a community member id, or a full name.");
    }
}
