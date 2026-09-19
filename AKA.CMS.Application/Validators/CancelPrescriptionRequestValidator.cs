using AKA.CMS.Application.DTOs;
using AKA.CMS.Application.Interfaces;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CancelPrescriptionRequestValidator : AbstractValidator<CancelPrescriptionRequest>
{
    public CancelPrescriptionRequestValidator()
    {
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}
