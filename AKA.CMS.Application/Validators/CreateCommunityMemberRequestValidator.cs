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
        // Mobile "Register New Case" screen marks Age as required.
        RuleFor(x => x.Age).NotNull().InclusiveBetween(0, 120);
        RuleFor(x => x.RegionCouncil).MaximumLength(100);
        RuleFor(x => x.LocalCouncil).MaximumLength(100);
        RuleFor(x => x.Village).MaximumLength(100);
        RuleFor(x => x.JkAttend).MaximumLength(100);
        RuleFor(x => x.EmploymentEducation).MaximumLength(200);
        RuleFor(x => x.MaritalStatus).MaximumLength(30);
        RuleFor(x => x.NumberOfChildren).GreaterThanOrEqualTo(0).When(x => x.NumberOfChildren.HasValue);
        RuleFor(x => x.LanguagesSpoken).MaximumLength(200);
        RuleFor(x => x.HealthInsurance).MaximumLength(50);
        RuleFor(x => x.GpUsualCare).MaximumLength(200);
        RuleFor(x => x.PriorMhTreatment).MaximumLength(50);
        RuleFor(x => x.ConnectedToMhCare).MaximumLength(50);
        RuleFor(x => x.CareProviderName).MaximumLength(200);
    }
}
