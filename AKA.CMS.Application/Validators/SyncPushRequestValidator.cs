using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class SyncPushRequestValidator : AbstractValidator<SyncPushRequest>
{
    private static readonly string[] Actions = ["CREATE", "UPDATE", "DELETE"];

    public SyncPushRequestValidator()
    {
        RuleFor(x => x.IdempotencyKey).NotEmpty().MaximumLength(100);
        RuleFor(x => x.DeviceId).NotEmpty().MaximumLength(100);
        RuleFor(x => x.EntityType).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Action).Must(a => Actions.Contains(a))
            .WithMessage("Action must be CREATE, UPDATE or DELETE.");
        RuleFor(x => x.PayloadJson).NotEmpty();
    }
}
