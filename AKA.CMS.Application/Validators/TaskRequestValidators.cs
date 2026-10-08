using AKA.CMS.Application.DTOs;
using FluentValidation;

namespace AKA.CMS.Application.Validators;

public sealed class CreateTaskRequestValidator : AbstractValidator<CreateTaskRequest>
{
    private static readonly string[] Priorities = ["High", "Medium", "Low"];

    public CreateTaskRequestValidator()
    {
        RuleFor(x => x.Title).NotEmpty().MaximumLength(200);
        RuleFor(x => x.Description).MaximumLength(4000);
        RuleFor(x => x.CaseId).GreaterThan(0);
        RuleFor(x => x.TaskType).MaximumLength(50);
        RuleFor(x => x.Priority).NotEmpty().Must(p => Priorities.Contains(p))
            .WithMessage("Priority must be High, Medium or Low.");
        RuleFor(x => x.DueDate).NotEmpty();
        RuleFor(x => x.NotifyRecipients).MaximumLength(500);
    }
}

public sealed class UpdateTaskStatusRequestValidator : AbstractValidator<UpdateTaskStatusRequest>
{
    private static readonly string[] Statuses = ["Pending", "InProgress", "Completed", "Cancelled"];

    public UpdateTaskStatusRequestValidator()
    {
        RuleFor(x => x.Status).NotEmpty().Must(s => Statuses.Contains(s))
            .WithMessage("Status must be Pending, InProgress, Completed or Cancelled.");
        RuleFor(x => x.RowVersion).NotEmpty();
    }
}

public sealed class AssignTaskRequestValidator : AbstractValidator<AssignTaskRequest>
{
    public AssignTaskRequestValidator()
    {
        RuleFor(x => x.RowVersion).NotEmpty();
        RuleFor(x => x).Must(x => x.AssignedToRoleId.HasValue || x.AssignedToUserId.HasValue)
            .WithMessage("Assign to a role, a user, or both.");
    }
}
