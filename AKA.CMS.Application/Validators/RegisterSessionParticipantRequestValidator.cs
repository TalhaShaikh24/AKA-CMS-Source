using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class RegisterSessionParticipantRequestValidator : AbstractValidator<RegisterSessionParticipantRequest>
{
    public RegisterSessionParticipantRequestValidator()
    {
        RuleFor(x => x).Must(x => x.CommunityMemberId.HasValue
                || !string.IsNullOrWhiteSpace(x.ParticipantName))
            .WithMessage("CommunityMemberId or ParticipantName is required.");
        RuleFor(x => x.CommunityMemberId).GreaterThan(0)
            .When(x => x.CommunityMemberId.HasValue);
        RuleFor(x => x.ParticipantName).MaximumLength(200);
    }
}
