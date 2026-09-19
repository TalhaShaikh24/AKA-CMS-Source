using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class UpdateReferralStatusRequestValidator : AbstractValidator<UpdateReferralStatusRequest>
{
    private static readonly string[] Statuses =
        ["ACCEPTED", "REJECTED", "CANCELLED", "COMPLETED"];

    public UpdateReferralStatusRequestValidator()
    {
        RuleFor(x => x.NewStatus)
            .NotEmpty()
            .Must(s => Statuses.Contains(s.ToUpperInvariant()))
            .WithMessage("NewStatus must be ACCEPTED, REJECTED, CANCELLED or COMPLETED.");
        RuleFor(x => x.RejectionReason)
            .NotEmpty()
            .When(x => x.NewStatus.Equals("REJECTED", StringComparison.OrdinalIgnoreCase))
            .WithMessage("A rejection reason is required to reject a referral.");
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}
