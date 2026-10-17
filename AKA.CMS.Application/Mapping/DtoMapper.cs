using AKA.CMS.Application.DTOs;
using AKA.CMS.Domain.Entities;

namespace AKA.CMS.Application.Mapping;

public static class DtoMapper
{
    public static UserDto ToDto(this User user) => new(
        user.UserId,
        user.Username,
        user.Email,
        user.IsActive,
        user.IsLocked,
        user.IsAdmin,
        user.Roles);

    public static RoleDto ToDto(this Role role) => new(
        role.RoleId,
        role.Description,
        role.IsActive);

    public static PermissionDto ToDto(this ControllerAction action) => new(
        action.Id,
        action.ControllerName,
        action.Action,
        action.PolicyName);

    public static FacilityDto ToDto(this Facility facility) => new(
        facility.FacilityId,
        facility.FacilityCode,
        facility.FacilityName,
        facility.FacilityType,
        facility.Region,
        facility.Address,
        facility.Phone,
        facility.IsActive,
        facility.RowVersion);

    public static RegionDto ToDto(this Region region) => new(
        region.RegionId,
        region.RegionName,
        region.IsActive,
        region.RowVersion);

    public static LocalCouncilDto ToDto(this LocalCouncil council) => new(
        council.CouncilId,
        council.RegionId,
        council.RegionName,
        council.CouncilName,
        council.IsActive,
        council.RowVersion);

    public static VillageDto ToDto(this Village village) => new(
        village.VillageId,
        village.CouncilId,
        village.CouncilName,
        village.VillageName,
        village.IsActive,
        village.RowVersion);

    public static TaskDto ToDto(this TaskItem task) => new(
        task.TaskId,
        task.Title,
        task.Description,
        task.CaseId,
        task.CaseNumber,
        task.PatientName,
        task.TaskType,
        task.Priority,
        DateOnly.FromDateTime(task.DueDate),
        task.AssignedToRoleId,
        task.AssignedRoleName,
        task.AssignedToUserId,
        task.AssignedUserName,
        task.NotifyRecipients,
        task.Status,
        task.CompletedAt,
        task.RowVersion);

    public static CommunityMemberDto ToDto(this CommunityMember member) => new(
        member.MemberId,
        member.MrNo,
        member.FullName,
        member.FatherName,
        member.Gender,
        member.DateOfBirth,
        member.Cnic,
        member.Phone,
        member.Address,
        member.IsActive,
        member.Age,
        member.RegionCouncil,
        member.LocalCouncil,
        member.Village,
        member.JkAttend,
        member.EmploymentEducation,
        member.MaritalStatus,
        member.NumberOfChildren,
        member.LanguagesSpoken,
        member.HealthInsurance,
        member.GpUsualCare,
        member.PriorMhTreatment,
        member.ConnectedToMhCare,
        member.CareProviderName,
        member.FirstName,
        member.LastName,
        member.DateOfCall,
        member.EntryPoint,
        member.ReturningCaller,
        member.ConsentToProceed);

    public static PatientSearchResultDto ToDto(this PatientSearchHit hit) => new(
        hit.Source,
        hit.MemberId,
        hit.MrNo,
        hit.FullName,
        hit.Gender,
        hit.Phone,
        hit.UnitCode,
        hit.LastEncounterAt);

    public static ResolveIdentityResponse ToResolveResponse(this HisMrMapping mapping, bool wasCreated) => new(
        mapping.MappingId,
        mapping.MrNo,
        mapping.IsDummy,
        wasCreated,
        mapping.UnitCode,
        mapping.ResolvedMrNo,
        mapping.RowVersion);

    public static FacilityMrBlockDto ToDto(this FacilityMrBlock block) => new(
        block.FacilityMrBlockId,
        block.UnitCode,
        block.MrPrefix,
        block.BlockStart,
        block.BlockEnd,
        block.NextSequence,
        block.IsPlaceholder,
        block.IsActive);

    public static CaseDto ToDto(this Case @case) => new(
        @case.CaseId,
        @case.CaseNumber,
        @case.CommunityMemberId,
        @case.MemberName,
        @case.MemberMrNo,
        @case.MemberAge,
        @case.MemberGender,
        @case.MemberVillage,
        @case.SourceType,
        @case.Status,
        @case.StatusName,
        @case.CurrentStep,
        @case.AssignedToUserId,
        @case.AssignedToUsername,
        @case.PriorityLevel,
        @case.Notes,
        @case.RowVersion,
        @case.CreatedAt,
        @case.ModifiedAt);

    public static AllowedTransitionDto ToDto(this WorkflowTransition transition, bool canPerform) => new(
        transition.ActionCode,
        transition.ActionName,
        transition.FromState,
        transition.ToState,
        transition.ToStateName,
        transition.RequiredPermissionName,
        canPerform);

    public static CaseHistoryDto ToDto(this CaseHistory history) => new(
        history.HistoryId,
        history.CaseId,
        history.FromState,
        history.ToState,
        history.ActionCode,
        history.Comment,
        history.PerformedBy,
        history.PerformedByUsername,
        history.PerformedAt);

    public static ScreeningRiskBandDto ToDto(this ScreeningRiskBand band) => new(
        band.BandCode,
        band.BandName,
        band.MinScore,
        band.MaxScore);

    public static ScreeningToolDto ToDto(this ScreeningTool tool) => new(
        tool.ToolCode,
        tool.ToolName,
        tool.Description,
        tool.ItemCount,
        tool.MaxItemScore,
        tool.MinScore,
        tool.MaxScore,
        tool.Bands.Select(b => b.ToDto()).ToList());

    public static ScreeningDto ToDto(this Screening screening) => new(
        screening.ScreeningId,
        screening.CaseId,
        screening.CommunityMemberId,
        screening.ToolCode,
        screening.ToolName,
        ParseItemScores(screening.ItemScores),
        screening.RawScore,
        screening.RiskLevel,
        screening.RiskLevelName,
        screening.SubscaleScoresJson,
        screening.MentalHealthSynced,
        screening.MentalHealthCode,
        screening.ScreenedBy,
        screening.ScreenedByUsername,
        screening.ScreenedAt,
        screening.RowVersion);

    private static IReadOnlyList<int> ParseItemScores(string itemScoresJson)
    {
        try
        {
            return System.Text.Json.JsonSerializer.Deserialize<int[]>(itemScoresJson) ?? [];
        }
        catch (System.Text.Json.JsonException)
        {
            return [];
        }
    }

    public static RiskRoutingRuleDto ToDto(this RiskRoutingRule rule) => new(
        rule.RiskCategory,
        rule.DisplayName,
        rule.SlaHours,
        rule.ReferralTargets.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries),
        rule.RequiresSupervisorAlert,
        ParseCarePlanSteps(rule.CarePlanStepsJson));

    public static ActionCarePlanDto ToDto(this ActionCarePlan plan) => new(
        plan.ActionCarePlanId,
        plan.CaseId,
        plan.RiskCategory,
        plan.Title,
        ParseCarePlanSteps(plan.StepsJson),
        plan.Status,
        plan.CreatedBy,
        plan.CreatedByUsername,
        plan.CreatedAt,
        plan.RowVersion);

    public static ReferralDto ToDto(this Referral referral) => new(
        referral.ReferralId,
        referral.ReferralNumber,
        referral.CaseId,
        referral.CaseNumber,
        referral.ReferredTo,
        referral.Status,
        referral.RejectionReason,
        referral.ParentReferralId,
        referral.ParentReferralNumber,
        referral.SlaDueAt,
        referral.Notes,
        referral.CreatedBy,
        referral.CreatedByUsername,
        referral.CreatedAt,
        referral.RowVersion);

    public static CaseCommentDto ToDto(this CaseComment comment) => new(
        comment.CaseCommentId,
        comment.CaseId,
        comment.CommentType,
        comment.Comment,
        comment.CreatedBy,
        comment.CreatedByUsername,
        comment.CreatedAt);

    public static CarerDto ToDto(this Carer carer) => new(
        carer.CarerId,
        carer.CaseId,
        carer.FullName,
        carer.Relationship,
        carer.Phone,
        carer.IsPrimary,
        carer.CreatedBy,
        carer.CreatedByUsername,
        carer.CreatedAt,
        carer.RowVersion);

    public static QueueEntryDto ToDto(this CaseAssignmentQueueEntry entry) => new(
        entry.QueueId,
        entry.CaseId,
        entry.CaseNumber,
        entry.RiskCategory,
        entry.SlaDueAt,
        entry.AssignedToUserId,
        entry.AssignedToUsername,
        entry.Status,
        entry.EnqueuedBy,
        entry.EnqueuedByUsername,
        entry.EnqueuedAt,
        entry.RowVersion);

    public static CrisisTypeDto ToDto(this CrisisType type) => new(
        type.CrisisTypeCode,
        type.DisplayName,
        type.DefaultSeverity,
        type.Description,
        type.SortOrder);

    public static HelplineCallDto ToDto(this HelplineCall call) => new(
        call.HelplineCallId,
        call.CallerName,
        call.CallerPhone,
        call.CaseId,
        call.CrisisTypeCodes,
        call.CrisisSeverity,
        call.CallNotes,
        call.HandledBy,
        call.HandledByUsername,
        call.CallStartedAt,
        call.CreatedAt,
        call.RowVersion);

    public static CrisisEventDto ToDto(this CrisisEvent @event) => new(
        @event.CrisisEventId,
        @event.CaseId,
        @event.CrisisTypeCode,
        @event.CrisisTypeName,
        @event.Severity,
        @event.TriggerSource,
        @event.Status,
        @event.Notes,
        @event.CreatedBy,
        @event.CreatedByUsername,
        @event.CreatedAt,
        @event.UpdatedAt,
        @event.RowVersion);

    public static SafetyPlanDto ToDto(this SafetyPlan plan) => new(
        plan.SafetyPlanId,
        plan.CaseId,
        plan.WarningSigns,
        plan.CopingStrategies,
        plan.SupportContactsJson,
        plan.CreatedBy,
        plan.CreatedByUsername,
        plan.CreatedAt,
        plan.RowVersion);

    public static AwarenessSessionDto ToDto(this AwarenessSession session) => new(
        session.SessionId,
        session.SessionCode,
        session.Title,
        session.FacilityCode,
        session.SessionDate,
        session.ConductedBy,
        session.Topic,
        session.TargetGroup,
        session.Venue,
        session.MaleCount,
        session.FemaleCount,
        session.OtherCount,
        session.Notes,
        session.RowVersion,
        session.ParticipantCount,
        session.CreatedAt);

    public static SessionParticipantDto ToDto(this SessionParticipant participant) => new(
        participant.ParticipantId,
        participant.SessionId,
        participant.CommunityMemberId,
        participant.MemberName,
        participant.ParticipantName,
        participant.Attended,
        participant.ConsentedToScreening,
        participant.ScreeningId,
        participant.CreatedAt);

    public static CaseSourceMappingDto ToDto(this CaseSourceMapping mapping) => new(
        mapping.MappingId,
        mapping.CaseId,
        mapping.SourceType,
        mapping.SourceDisplayName,
        mapping.SourceReferenceId,
        mapping.CreatedAt);

    public static CaseSourceTypeDto ToDto(this CaseSourceType type) => new(
        type.SourceTypeCode,
        type.DisplayName,
        type.Description,
        type.IsClientSourced,
        type.SortOrder);

    private static readonly System.Text.Json.JsonSerializerOptions CarePlanStepsJsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    private static IReadOnlyList<CarePlanStepDto> ParseCarePlanSteps(string stepsJson)
    {
        try
        {
            return System.Text.Json.JsonSerializer.Deserialize<CarePlanStepDto[]>(stepsJson, CarePlanStepsJsonOptions) ?? [];
        }
        catch (System.Text.Json.JsonException)
        {
            return [];
        }
    }

    public static TreatmentPlanDto ToDto(this TreatmentPlan plan) => new(
        plan.PlanId,
        plan.CaseId,
        plan.PlanTrack,
        plan.Title,
        plan.Goals,
        plan.PlannedInterventions,
        plan.StartDate,
        plan.PlannedEndDate,
        plan.Status,
        plan.RowVersion,
        plan.PsychSessionCount,
        plan.PrescriptionCount,
        plan.CreatedAt);

    public static PsychologicalSessionDto ToDto(this PsychologicalSession session) => new(
        session.SessionId,
        session.PlanId,
        session.CaseId,
        session.TherapistUserId,
        session.SessionDate,
        session.ModalityCode,
        session.ModalityName,
        session.DurationMinutes,
        session.SessionNotes,
        session.OutcomeNotes,
        session.NextSessionDate,
        session.RowVersion,
        session.CreatedAt);

    public static MedicationDto ToDto(this Medication medication) => new(
        medication.MedicationId,
        medication.MedicationCode,
        medication.GenericName,
        medication.Strength,
        medication.DosageForm,
        medication.ClinicalConfirmationPending,
        medication.SortOrder);

    public static MedicationPrescriptionDto ToDto(this MedicationPrescription prescription) => new(
        prescription.PrescriptionId,
        prescription.RxNumber,
        prescription.CaseId,
        prescription.PlanId,
        prescription.MedicationId,
        prescription.MedicationCode,
        prescription.GenericName,
        prescription.Strength,
        prescription.DosageForm,
        prescription.PrescribedByUserId,
        prescription.DoseText,
        prescription.Frequency,
        prescription.DurationDays,
        prescription.Instructions,
        prescription.DiagnosisText,
        prescription.Status,
        prescription.RowVersion,
        prescription.CreatedAt,
        prescription.DispenseCount);

    public static FollowUpDto ToDto(this FollowUp followUp) => new(
        followUp.FollowUpId,
        followUp.CaseId,
        followUp.ScheduledDate,
        followUp.ActualDate,
        followUp.FollowUpType,
        followUp.AssignedToUserId,
        followUp.Notes,
        followUp.Status,
        followUp.OutcomeNotes,
        followUp.RowVersion,
        followUp.CreatedAt);

    public static LostToFollowUpDto ToDto(this LostToFollowUp tracking) => new(
        tracking.LtfuId,
        tracking.CaseId,
        tracking.MissedCount,
        tracking.LastContactDate,
        tracking.LtfuDeclaredDate,
        tracking.Status,
        tracking.ReEngagementNotes,
        tracking.RowVersion,
        tracking.CreatedAt);

    public static CaseClosureDto ToDto(this CaseClosure closure) => new(
        closure.ClosureId,
        closure.CaseId,
        closure.ClosureReason,
        closure.SymptomRemission,
        closure.ClosureSummary,
        closure.ApprovalStatus,
        closure.RequestedByUserId,
        closure.RequestedAt,
        closure.ApprovedByUserId,
        closure.ApprovedAt,
        closure.RejectionReason,
        closure.RowVersion,
        closure.CreatedAt);

    public static SupervisionLogDto ToDto(this SupervisionLog log) => new(
        log.SupervisionLogId,
        log.CaseId,
        log.SupervisorUserId,
        log.ReviewDate,
        log.Findings,
        log.ActionItems,
        log.Rating,
        log.RowVersion,
        log.CreatedAt);

    public static DueFollowUpDto ToDto(this DueFollowUp due) => new(
        due.CaseId,
        due.CaseNumber,
        due.PriorityLevel,
        due.CaseStatus,
        due.LastContactDate,
        due.DaysSinceContact,
        due.FrequencyDays);

    public static NotificationDto ToDto(this Notification notification) => new(
        notification.NotificationId,
        notification.RecipientRole,
        notification.RecipientUserId,
        notification.Title,
        notification.Body,
        notification.RelatedCaseId,
        notification.RelatedEntity,
        notification.RelatedEntityId,
        notification.IsRead,
        notification.ReadAt,
        notification.Status,
        notification.PushPayload,
        notification.CreatedAt);

    public static AttachmentDto ToDto(this CaseAttachment attachment) => new(
        attachment.AttachmentId,
        attachment.CaseId,
        attachment.FileName,
        attachment.ContentType,
        attachment.FileSizeBytes,
        attachment.UploadedBy,
        attachment.UploadedAt,
        attachment.CreatedAt);

    public static LookupItemDto ToDto(this LookupItem item) => new(
        item.Code,
        item.Name,
        item.Description,
        item.SortOrder,
        item.IsActive,
        item.Extra);

    public static WorkflowStateDto ToDto(this WorkflowState state) => new(
        state.StateCode,
        state.StateName,
        state.Description,
        state.IsInitial,
        state.IsTerminal,
        state.SortOrder);

    public static WorkflowTransitionDto ToDto(this WorkflowTransition transition) => new(
        transition.TransitionId,
        transition.FromState,
        transition.ActionCode,
        transition.ActionName,
        transition.ToState,
        transition.RequiredPermissionName,
        transition.SortOrder,
        transition.IsActive,
        transition.RowVersion);
}
