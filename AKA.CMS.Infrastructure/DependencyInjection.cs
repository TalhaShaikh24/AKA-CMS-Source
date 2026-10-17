using AKA.CMS.Application.Interfaces;
using AKA.CMS.Application.Services;
using AKA.CMS.Infrastructure.Persistence;
using AKA.CMS.Infrastructure.Repositories;
using AKA.CMS.Infrastructure.Security;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace AKA.CMS.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddSingleton(configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>()
            ?? throw new InvalidOperationException("Jwt settings are missing."));
        services.AddSingleton(configuration.GetSection(SmtpOptions.SectionName).Get<SmtpOptions>()
            ?? new SmtpOptions());
        services.AddSingleton(configuration.GetSection(PasswordResetOptions.SectionName).Get<PasswordResetOptions>()
            ?? new PasswordResetOptions());

        services.AddSingleton<DapperContext>();

        services.AddScoped<IAuthRepository, AuthRepository>();
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IRoleRepository, RoleRepository>();
        services.AddScoped<IPermissionRepository, PermissionRepository>();
        services.AddScoped<IPatientRepository, PatientRepository>();
        services.AddScoped<IFacilityRepository, FacilityRepository>();
        services.AddScoped<IGeographyRepository, GeographyRepository>();
        services.AddScoped<ITaskRepository, TaskRepository>();
        services.AddScoped<ICaseRepository, CaseRepository>();
        services.AddScoped<IScreeningRepository, ScreeningRepository>();
        services.AddScoped<IScreeningToolRepository, ScreeningToolRepository>();
        services.AddScoped<IRiskAssessmentRepository, RiskAssessmentRepository>();
        services.AddScoped<ISettingsRepository, SettingsRepository>();
        services.AddScoped<ICarePlanRepository, CarePlanRepository>();
        services.AddScoped<IReferralRepository, ReferralRepository>();
        services.AddScoped<ICaseCommentRepository, CaseCommentRepository>();
        services.AddScoped<ICarerRepository, CarerRepository>();
        services.AddScoped<IAssignmentQueueRepository, AssignmentQueueRepository>();
        services.AddScoped<IHelplineRepository, HelplineRepository>();
        services.AddScoped<ICrisisRepository, CrisisRepository>();
        services.AddScoped<ISafetyPlanRepository, SafetyPlanRepository>();
        services.AddScoped<IAwarenessSessionRepository, AwarenessSessionRepository>();
        services.AddScoped<ISessionParticipantRepository, SessionParticipantRepository>();
        services.AddScoped<ICaseSourceRepository, CaseSourceRepository>();
        services.AddScoped<ITreatmentPlanRepository, TreatmentPlanRepository>();
        services.AddScoped<IPsychologicalSessionRepository, PsychologicalSessionRepository>();
        services.AddScoped<IMedicationRepository, MedicationRepository>();
        services.AddScoped<IFollowUpRepository, FollowUpRepository>();
        services.AddScoped<ICaseClosureRepository, CaseClosureRepository>();
        services.AddScoped<ISupervisionRepository, SupervisionRepository>();
        services.AddScoped<INotificationRepository, NotificationRepository>();
        services.AddScoped<ICaseAttachmentRepository, CaseAttachmentRepository>();
        services.AddScoped<IAuditLogRepository, AuditLogRepository>();
        services.AddScoped<ISyncRepository, SyncRepository>();
        services.AddScoped<IHealthRepository, HealthRepository>();

        services.AddScoped<IAuthService, AuthService>();
        services.AddScoped<IUserService, UserService>();
        services.AddScoped<IRoleService, RoleService>();
        services.AddScoped<IPermissionService, PermissionService>();
        services.AddScoped<IPatientService, PatientService>();
        services.AddScoped<IFacilityService, FacilityService>();
        services.AddScoped<IGeographyService, GeographyService>();
        services.AddScoped<ITaskService, TaskService>();
        services.AddScoped<ICaseService, CaseService>();
        services.AddScoped<IScreeningService, ScreeningService>();
        services.AddScoped<IScreeningToolService, ScreeningToolService>();
        services.AddScoped<IRiskAssessmentService, RiskAssessmentService>();
        services.AddScoped<ISettingsService, SettingsService>();
        services.AddScoped<ICarePlanService, CarePlanService>();
        services.AddScoped<IReferralService, ReferralService>();
        services.AddScoped<ICaseCommentService, CaseCommentService>();
        services.AddScoped<ICarerService, CarerService>();
        services.AddScoped<IAssignmentService, AssignmentService>();
        services.AddScoped<ICrisisDetectionService, CrisisDetectionService>();
        services.AddScoped<IHelplineService, HelplineService>();
        services.AddScoped<ICrisisService, CrisisService>();
        services.AddScoped<ISafetyPlanService, SafetyPlanService>();
        services.AddScoped<IAwarenessSessionService, AwarenessSessionService>();
        services.AddScoped<ICaseSourceService, CaseSourceService>();
        services.AddScoped<ITreatmentPlanService, TreatmentPlanService>();
        services.AddScoped<IPsychologicalSessionService, PsychologicalSessionService>();
        services.AddScoped<IMedicationService, MedicationService>();
        services.AddScoped<IFollowUpService, FollowUpService>();
        services.AddScoped<ILtfuService, LtfuService>();
        services.AddScoped<IFollowUpDueService, FollowUpDueService>();
        services.AddScoped<ICaseClosureService, CaseClosureService>();
        services.AddScoped<ISupervisionService, SupervisionService>();
        services.AddScoped<INotificationService, NotificationService>();
        services.AddScoped<ICaseAttachmentService, CaseAttachmentService>();
        services.AddScoped<IAuditLogService, AuditLogService>();
        services.AddScoped<ISyncService, SyncService>();
        services.AddScoped<IHealthService, HealthService>();
        services.AddScoped<ILookupRepository, LookupRepository>();
        services.AddScoped<IWorkflowConfigRepository, WorkflowConfigRepository>();
        services.AddScoped<IReportRepository, ReportRepository>();
        services.AddScoped<ILookupService, LookupService>();
        services.AddScoped<IWorkflowConfigService, WorkflowConfigService>();
        services.AddScoped<IReportService, ReportService>();

        services.AddScoped<IJwtTokenService, JwtTokenService>();
        services.AddScoped<IPasswordHasher, BCryptPasswordHasher>();
        services.AddScoped<IEmailSender, Email.SmtpEmailSender>();

        return services;
    }
}
