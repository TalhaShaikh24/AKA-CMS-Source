namespace AKA.CMS.Infrastructure;

public static class StoredProcedures
{
    public const string HealthCheck = "sp_CMS_Health_Check";

    public const string AuthGetUserByUsername = "sp_CMS_Auth_GetUserByUsername";
    public const string AuthGetUserById = "sp_CMS_Auth_GetUserById";
    public const string AuthGetUserByEmail = "sp_CMS_Auth_GetUserByEmail";
    public const string AuthGetUserPermissions = "sp_CMS_Auth_GetUserPermissions";
    public const string AuthGetAllPermissions = "sp_CMS_Auth_GetAllPermissions";
    public const string AuthSaveRefreshToken = "sp_CMS_Auth_SaveRefreshToken";
    public const string AuthGetRefreshToken = "sp_CMS_Auth_GetRefreshToken";
    public const string AuthRevokeRefreshToken = "sp_CMS_Auth_RevokeRefreshToken";
    public const string PasswordResetCreate = "sp_CMS_PasswordReset_Create";
    public const string PasswordResetComplete = "sp_CMS_PasswordReset_Complete";

    public const string UserGetById = "sp_CMS_User_GetById";
    public const string UserGetAll = "sp_CMS_User_GetAll";
    public const string UserCreate = "sp_CMS_User_Create";
    public const string UserUpdate = "sp_CMS_User_Update";
    public const string UserAssignRole = "sp_CMS_User_AssignRole";
    public const string UserRemoveRole = "sp_CMS_User_RemoveRole";

    public const string RoleGetAll = "sp_CMS_Role_GetAll";
    public const string RoleGetById = "sp_CMS_Role_GetById";
    public const string RoleCreate = "sp_CMS_Role_Create";
    public const string RoleGetPermissions = "sp_CMS_Role_GetPermissions";
    public const string RoleAssignPermission = "sp_CMS_Role_AssignPermission";
    public const string RoleRemovePermission = "sp_CMS_Role_RemovePermission";

    public const string PermissionGetCatalog = "sp_CMS_Permission_GetCatalog";

    public const string CommunityMemberCreate = "sp_CMS_CommunityMember_Create";
    public const string CommunityMemberGetById = "sp_CMS_CommunityMember_GetById";
    public const string CommunityMemberSearch = "sp_CMS_CommunityMember_Search";
    public const string HisMrMappingResolveOrCreate = "sp_CMS_HisMrMapping_ResolveOrCreate";
    public const string HisMrMappingRemapToRealMr = "sp_CMS_HisMrMapping_RemapToRealMr";
    public const string FacilityMrBlockGetAll = "sp_CMS_FacilityMrBlock_GetAll";
    public const string FacilityMrBlockUpsert = "sp_CMS_FacilityMrBlock_Upsert";

    public const string CaseCreate = "sp_CMS_Case_Create";
    public const string CaseGetById = "sp_CMS_Case_GetById";
    public const string CaseUpdateDetails = "sp_CMS_Case_UpdateDetails";
    public const string CaseAssign = "sp_CMS_Case_Assign";
    public const string WorkflowTransitionApply = "sp_CMS_WorkflowTransition_Apply";
    public const string WorkflowTransitionGetAllowed = "sp_CMS_WorkflowTransition_GetAllowed";
    public const string CaseHistoryGetByCase = "sp_CMS_CaseHistory_GetByCase";

    public const string ScreeningToolGetAll = "sp_CMS_ScreeningTool_GetAll";
    public const string ScreeningSubmit = "sp_CMS_Screening_Submit";
    public const string ScreeningGetById = "sp_CMS_Screening_GetById";
    public const string ScreeningGetByCase = "sp_CMS_Screening_GetByCase";

    public const string RiskRoutingRuleGetAll = "sp_CMS_RiskRoutingRule_GetAll";
    public const string ActionCarePlanCreate = "sp_CMS_ActionCarePlan_Create";
    public const string ActionCarePlanGetByCase = "sp_CMS_ActionCarePlan_GetByCase";
    public const string AssignmentQueueEnqueue = "sp_CMS_CaseAssignmentQueue_Enqueue";
    public const string AssignmentQueueAssign = "sp_CMS_CaseAssignmentQueue_Assign";
    public const string AssignmentQueueGetPending = "sp_CMS_CaseAssignmentQueue_GetPending";
    public const string ReferralCreate = "sp_CMS_Referral_Create";
    public const string ReferralGetById = "sp_CMS_Referral_GetById";
    public const string ReferralUpdateStatus = "sp_CMS_Referral_UpdateStatus";
    public const string ReferralGetByCase = "sp_CMS_Referral_GetByCase";
    public const string CaseCommentAdd = "sp_CMS_CaseComment_Add";
    public const string CaseCommentGetByCase = "sp_CMS_CaseComment_GetByCase";
    public const string CarerAdd = "sp_CMS_Carer_Add";
    public const string CarerUpdate = "sp_CMS_Carer_Update";
    public const string CarerDeactivate = "sp_CMS_Carer_Deactivate";
    public const string CarerGetByCase = "sp_CMS_Carer_GetByCase";

    public const string HelplineCallLog = "sp_CMS_HelplineCall_Log";
    public const string HelplineCallGetById = "sp_CMS_HelplineCall_GetById";
    public const string HelplineCallGetList = "sp_CMS_HelplineCall_GetList";
    public const string CrisisEventTrigger = "sp_CMS_CrisisEvent_Trigger";
    public const string CrisisEventUpdateStatus = "sp_CMS_CrisisEvent_UpdateStatus";
    public const string CrisisEventGetById = "sp_CMS_CrisisEvent_GetById";
    public const string CrisisEventGetByCase = "sp_CMS_CrisisEvent_GetByCase";
    public const string CrisisTypeGetAll = "sp_CMS_CrisisType_GetAll";
    public const string SafetyPlanCreate = "sp_CMS_SafetyPlan_Create";
    public const string SafetyPlanGetById = "sp_CMS_SafetyPlan_GetById";
    public const string SafetyPlanGetByCase = "sp_CMS_SafetyPlan_GetByCase";

    public const string AwarenessSessionCreate = "sp_CMS_AwarenessSession_Create";
    public const string AwarenessSessionGetById = "sp_CMS_AwarenessSession_GetById";
    public const string AwarenessSessionGetList = "sp_CMS_AwarenessSession_GetList";
    public const string AwarenessSessionUpdate = "sp_CMS_AwarenessSession_Update";
    public const string SessionParticipantRegister = "sp_CMS_SessionParticipant_Register";
    public const string SessionParticipantGetList = "sp_CMS_SessionParticipant_GetList";
    public const string SessionParticipantLinkScreening = "sp_CMS_SessionParticipant_LinkScreening";
    public const string CaseSourceRecord = "sp_CMS_CaseSource_Record";
    public const string CaseSourceGetByCase = "sp_CMS_CaseSource_GetByCase";
    public const string CaseSourceTypeGetAll = "sp_CMS_CaseSourceType_GetAll";

    public const string TreatmentPlanCreate = "sp_CMS_TreatmentPlan_Create";
    public const string TreatmentPlanUpdate = "sp_CMS_TreatmentPlan_Update";
    public const string TreatmentPlanGetById = "sp_CMS_TreatmentPlan_GetById";
    public const string TreatmentPlanGetByCase = "sp_CMS_TreatmentPlan_GetByCase";
    public const string PsychologicalSessionRecord = "sp_CMS_PsychologicalSession_Record";
    public const string PsychologicalSessionGetByCase = "sp_CMS_PsychologicalSession_GetByCase";
    public const string MedicationDictionaryGetAll = "sp_CMS_MedicationDictionary_GetAll";
    public const string MedicationPrescriptionCreate = "sp_CMS_MedicationPrescription_Create";
    public const string MedicationPrescriptionCancel = "sp_CMS_MedicationPrescription_Cancel";
    public const string MedicationPrescriptionGetByCase = "sp_CMS_MedicationPrescription_GetByCase";
    public const string MedicationDispense = "sp_CMS_Medication_Dispense";

    public const string FollowUpSchedule = "sp_CMS_FollowUp_Schedule";
    public const string FollowUpRecordOutcome = "sp_CMS_FollowUp_RecordOutcome";
    public const string LostToFollowUpFlag = "sp_CMS_LostToFollowUp_Flag";
    public const string LostToFollowUpReEngage = "sp_CMS_LostToFollowUp_ReEngage";
    public const string FollowUpsGetByCase = "sp_CMS_FollowUps_GetByCase";
    public const string LostToFollowUpGetByCase = "sp_CMS_LostToFollowUp_GetByCase";
    public const string FollowUpGetDue = "sp_CMS_FollowUp_GetDue";
    public const string CaseClosureRequest = "sp_CMS_CaseClosure_Request";
    public const string CaseClosureApprove = "sp_CMS_CaseClosure_Approve";
    public const string CaseClosuresGetByCase = "sp_CMS_CaseClosures_GetByCase";
    public const string SupervisionLogCreate = "sp_CMS_SupervisionLog_Create";
    public const string SupervisionLogsGetByCase = "sp_CMS_SupervisionLogs_GetByCase";

    public const string SystemSettingGet = "sp_CMS_SystemSetting_Get";
    public const string NotificationCreate = "sp_CMS_Notification_Create";
    public const string NotificationGetByUser = "sp_CMS_Notification_GetByUser";
    public const string NotificationMarkAsRead = "sp_CMS_Notification_MarkAsRead";
    public const string NotificationMarkAllRead = "sp_CMS_Notification_MarkAllRead";
    public const string CaseAttachmentUpload = "sp_CMS_CaseAttachment_Upload";
    public const string CaseAttachmentGetByCase = "sp_CMS_CaseAttachment_GetByCase";
    public const string CaseAttachmentGetById = "sp_CMS_CaseAttachment_GetById";
    public const string AuditLogQuery = "sp_CMS_AuditLog_Query";
    public const string SyncOutboxPush = "sp_CMS_SyncOutbox_Push";
    public const string SyncPull = "sp_CMS_Sync_Pull";
    public const string SyncOutboxAck = "sp_CMS_SyncOutbox_Ack";

    public const string LookupGet = "sp_CMS_Lookup_Get";
    public const string WorkflowStateGetAll = "sp_CMS_WorkflowState_GetAll";
    public const string WorkflowTransitionGetAll = "sp_CMS_WorkflowTransition_GetAll";
    public const string WorkflowTransitionCreate = "sp_CMS_WorkflowTransition_Create";
    public const string WorkflowTransitionSetActive = "sp_CMS_WorkflowTransition_SetActive";
    public const string ReportCaseSummary = "sp_CMS_Report_CaseSummary";
    public const string ReportScreeningSummary = "sp_CMS_Report_ScreeningSummary";
    public const string ReportHelplineSummary = "sp_CMS_Report_HelplineSummary";
    public const string ReportFollowUpCompliance = "sp_CMS_Report_FollowUpCompliance";
    public const string ReportWorkload = "sp_CMS_Report_Workload";
}
