using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class SyncAckRequestValidator : AbstractValidator<SyncAckRequest>
{
    public SyncAckRequestValidator()
    {
        RuleFor(x => x.IdempotencyKey).NotEmpty().MaximumLength(100);
        RuleFor(x => x.DeviceId).NotEmpty().MaximumLength(100);
    }
}
