/* ============================================================
   AKA-CMS — Sprint 5 stored procedures (09)
   Module 3: Case Management, Assignment & Referral.

   One procedure per repository method. All write procs use
   TRY/CATCH + transactions + CMS_AuditLogs.

   Custom error codes (as before):
     50005 concurrency (RowVersion mismatch),
     50008 not found,
     50009 validation (used by screenings),
     50010 invalid status/transition or bad domain value.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_RiskRoutingRule_GetAll ----
   Routing rules (risk category -> SLA + referral targets + steps). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_RiskRoutingRule_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [RiskCategory], [DisplayName], [SlaHours], [ReferralTargets],
           [RequiresSupervisorAlert], [CarePlanStepsJson]
    FROM [dbo].[CMS_RiskRoutingRules]
    WHERE [IsActive] = 1
    ORDER BY [SlaHours];
END
GO

/* ---- sp_CMS_ActionCarePlan_Create ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_ActionCarePlan_Create]
    @CaseId       INT,
    @RiskCategory VARCHAR(20),
    @Title        NVARCHAR(200) = NULL,
    @StepsJson    NVARCHAR(MAX) = NULL,
    @CreatedBy    INT,
    @IpAddress    VARCHAR(45) = NULL,
    @NewPlanId    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @RiskCategory = UPPER(LTRIM(RTRIM(@RiskCategory)));

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    DECLARE @RuleSteps NVARCHAR(MAX);
    SELECT @RuleSteps = [CarePlanStepsJson]
    FROM [dbo].[CMS_RiskRoutingRules]
    WHERE [RiskCategory] = @RiskCategory AND [IsActive] = 1;

    IF @RuleSteps IS NULL
        THROW 50010, 'Invalid risk category. Expected HIGH, MODERATE or LOW.', 1;

    IF @StepsJson IS NULL SET @StepsJson = @RuleSteps;
    IF @Title IS NULL
        SET @Title = (SELECT [DisplayName] FROM [dbo].[CMS_RiskRoutingRules] WHERE [RiskCategory] = @RiskCategory)
                     + ' Action Care Plan';

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO [dbo].[CMS_ActionCarePlans]
            ([CaseId], [RiskCategory], [Title], [StepsJson], [Status], [CreatedBy], [IpAddress])
        VALUES
            (@CaseId, @RiskCategory, @Title, @StepsJson, 'ACTIVE', @CreatedBy, @IpAddress);

        SET @NewPlanId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_ActionCarePlans', CAST(@NewPlanId AS VARCHAR(50)), 'INSERT', @CreatedBy, @Title);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_ActionCarePlan_GetByCase ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_ActionCarePlan_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    SELECT p.[ActionCarePlanId], p.[CaseId], p.[RiskCategory], p.[Title], p.[StepsJson],
           p.[Status], p.[CreatedBy], u.[USERNAME] AS [CreatedByUsername],
           p.[CreatedAt], p.[RowVersion]
    FROM [dbo].[CMS_ActionCarePlans] p
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = p.[CreatedBy]
    WHERE p.[CaseId] = @CaseId AND p.[IsActive] = 1
    ORDER BY p.[ActionCarePlanId] DESC;
END
GO

/* ---- sp_CMS_CaseAssignmentQueue_Enqueue ----
   Idempotent: a second PENDING entry for the same case returns the
   existing QueueId instead of duplicating. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseAssignmentQueue_Enqueue]
    @CaseId      INT,
    @RiskCategory VARCHAR(20),
    @EnqueuedBy  INT,
    @IpAddress   VARCHAR(45) = NULL,
    @NewQueueId  INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @RiskCategory = UPPER(LTRIM(RTRIM(@RiskCategory)));

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    DECLARE @SlaHours INT;
    SELECT @SlaHours = [SlaHours]
    FROM [dbo].[CMS_RiskRoutingRules]
    WHERE [RiskCategory] = @RiskCategory AND [IsActive] = 1;

    IF @SlaHours IS NULL
        THROW 50010, 'Invalid risk category. Expected HIGH, MODERATE or LOW.', 1;

    SELECT @NewQueueId = [QueueId]
    FROM [dbo].[CMS_CaseAssignmentQueue]
    WHERE [CaseId] = @CaseId AND [Status] = 'PENDING' AND [IsActive] = 1;

    IF @NewQueueId IS NOT NULL
        RETURN;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO [dbo].[CMS_CaseAssignmentQueue]
            ([CaseId], [RiskCategory], [SlaDueAt], [Status], [EnqueuedBy], [IpAddress])
        VALUES
            (@CaseId, @RiskCategory,
             DATEADD(HOUR, @SlaHours, SYSUTCDATETIME()),
             'PENDING', @EnqueuedBy, @IpAddress);

        SET @NewQueueId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_CaseAssignmentQueue', CAST(@NewQueueId AS VARCHAR(50)), 'INSERT', @EnqueuedBy, @RiskCategory);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_CaseAssignmentQueue_Assign ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseAssignmentQueue_Assign]
    @QueueId         INT,
    @AssignedToUserId INT,
    @RowVersion      BINARY(8),
    @PerformedBy     INT,
    @IpAddress       VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentRowVersion BINARY(8);
    DECLARE @Status VARCHAR(20);

    SELECT @CurrentRowVersion = [RowVersion], @Status = [Status]
    FROM [dbo].[CMS_CaseAssignmentQueue]
    WHERE [QueueId] = @QueueId AND [IsActive] = 1;

    IF @CurrentRowVersion IS NULL
        THROW 50008, 'Assignment queue entry not found.', 1;

    IF @CurrentRowVersion <> @RowVersion
        THROW 50005, 'Assignment entry was modified by another user.', 1;

    IF @Status <> 'PENDING'
        THROW 50010, 'Only PENDING queue entries can be assigned.', 1;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERID] = @AssignedToUserId)
        THROW 50008, 'Assignee user not found.', 1;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE [dbo].[CMS_CaseAssignmentQueue]
        SET [AssignedToUserId] = @AssignedToUserId,
            [Status] = 'ASSIGNED',
            [AssignedAt] = SYSUTCDATETIME()
        WHERE [QueueId] = @QueueId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_CaseAssignmentQueue', CAST(@QueueId AS VARCHAR(50)), 'ASSIGN', @PerformedBy,
                'AssignedTo=' + CAST(@AssignedToUserId AS VARCHAR(20)));

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_CaseAssignmentQueue_GetPending ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseAssignmentQueue_GetPending]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT q.[QueueId], q.[CaseId], c.[CaseNumber], q.[RiskCategory], q.[SlaDueAt],
           q.[AssignedToUserId], u.[USERNAME] AS [AssignedToUsername], q.[Status],
           q.[EnqueuedBy], e.[USERNAME] AS [EnqueuedByUsername], q.[EnqueuedAt],
           q.[RowVersion]
    FROM [dbo].[CMS_CaseAssignmentQueue] q
    INNER JOIN [dbo].[CMS_Cases] c ON c.[CaseId] = q.[CaseId]
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = q.[AssignedToUserId]
    LEFT JOIN [dbo].[USERS] e ON e.[USERID] = q.[EnqueuedBy]
    WHERE q.[Status] = 'PENDING' AND q.[IsActive] = 1
    ORDER BY q.[SlaDueAt];
END
GO

/* ---- sp_CMS_Referral_Create ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Referral_Create]
    @CaseId       INT,
    @ReferredTo   VARCHAR(40),
    @SlaDueAt     DATETIME2 = NULL,
    @Notes        NVARCHAR(500) = NULL,
    @CreatedBy    INT,
    @IpAddress    VARCHAR(45) = NULL,
    @NewReferralId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @ReferredTo = UPPER(LTRIM(RTRIM(@ReferredTo)));

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    IF @ReferredTo NOT IN ('PSYCHOLOGIST', 'PSYCHIATRIST', 'PSYCHOSOCIAL', 'EMERGENCY_SERVICES')
        THROW 50010, 'Invalid ReferredTo. Expected PSYCHOLOGIST, PSYCHIATRIST, PSYCHOSOCIAL or EMERGENCY_SERVICES.', 1;

    IF @SlaDueAt IS NULL
        SET @SlaDueAt = DATEADD(HOUR, 24, SYSUTCDATETIME());

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @ReferralNumber VARCHAR(30) =
            'REF-' + CAST(YEAR(SYSUTCDATETIME()) AS VARCHAR(4)) + '-'
            + RIGHT('000000' + CAST(NEXT VALUE FOR [dbo].[CMS_ReferralNumberSeq] AS VARCHAR(10)), 6);

        INSERT INTO [dbo].[CMS_Referrals]
            ([ReferralNumber], [CaseId], [ReferredTo], [Status], [SlaDueAt], [Notes], [CreatedBy], [IpAddress])
        VALUES
            (@ReferralNumber, @CaseId, @ReferredTo, 'PENDING', @SlaDueAt, @Notes, @CreatedBy, @IpAddress);

        SET @NewReferralId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Referrals', CAST(@NewReferralId AS VARCHAR(50)), 'INSERT', @CreatedBy, @ReferralNumber);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Referral_UpdateStatus ----
   Accept/Reject per the handoff DoD: REJECTED does not mutate the
   original row beyond marking it REJECTED — it creates a NEW
   PENDING referral row linked via ParentReferralId (re-route),
   whose id is returned in @NewReferralId. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Referral_UpdateStatus]
    @ReferralId      INT,
    @NewStatus       VARCHAR(20),
    @RejectionReason NVARCHAR(500) = NULL,
    @RowVersion      BINARY(8),
    @PerformedBy     INT,
    @IpAddress       VARCHAR(45) = NULL,
    @NewReferralId   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @NewStatus = UPPER(LTRIM(RTRIM(@NewStatus)));
    SET @NewReferralId = NULL;

    DECLARE @CurrentRowVersion BINARY(8);
    DECLARE @CurrentStatus VARCHAR(20);
    DECLARE @CaseId INT;
    DECLARE @ReferredTo VARCHAR(40);
    DECLARE @SlaDueAt DATETIME2;

    SELECT @CurrentRowVersion = [RowVersion], @CurrentStatus = [Status],
           @CaseId = [CaseId], @ReferredTo = [ReferredTo], @SlaDueAt = [SlaDueAt]
    FROM [dbo].[CMS_Referrals]
    WHERE [ReferralId] = @ReferralId AND [IsActive] = 1;

    IF @CurrentRowVersion IS NULL
        THROW 50008, 'Referral not found.', 1;

    IF @CurrentRowVersion <> @RowVersion
        THROW 50005, 'Referral was modified by another user.', 1;

    DECLARE @Allowed BIT = 0;
    IF @CurrentStatus = 'PENDING' AND @NewStatus IN ('ACCEPTED', 'REJECTED', 'CANCELLED') SET @Allowed = 1;
    IF @CurrentStatus = 'ACCEPTED' AND @NewStatus IN ('COMPLETED', 'CANCELLED') SET @Allowed = 1;

    IF @Allowed = 0
        THROW 50010, 'Invalid referral status transition.', 1;

    IF @NewStatus = 'REJECTED' AND (NULLIF(LTRIM(RTRIM(@RejectionReason)), '') IS NULL)
        THROW 50010, 'A rejection reason is required to reject a referral.', 1;

    BEGIN TRY
        BEGIN TRAN;

        IF @NewStatus = 'REJECTED'
        BEGIN
            /* Mark the old row rejected... */
            UPDATE [dbo].[CMS_Referrals]
            SET [Status] = 'REJECTED', [RejectionReason] = @RejectionReason
            WHERE [ReferralId] = @ReferralId;

            /* ...and create the re-route row (original record is kept). */
            DECLARE @ReferralNumber VARCHAR(30) =
                'REF-' + CAST(YEAR(SYSUTCDATETIME()) AS VARCHAR(4)) + '-'
                + RIGHT('000000' + CAST(NEXT VALUE FOR [dbo].[CMS_ReferralNumberSeq] AS VARCHAR(10)), 6);

            INSERT INTO [dbo].[CMS_Referrals]
                ([ReferralNumber], [CaseId], [ReferredTo], [Status],
                 [ParentReferralId], [SlaDueAt], [Notes], [CreatedBy], [IpAddress])
            VALUES
                (@ReferralNumber, @CaseId, @ReferredTo, 'PENDING',
                 @ReferralId, @SlaDueAt,
                 'Re-routed after rejection: ' + @RejectionReason, @PerformedBy, @IpAddress);

            SET @NewReferralId = SCOPE_IDENTITY();

            INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
            VALUES ('CMS_Referrals', CAST(@ReferralId AS VARCHAR(50)), 'REJECT', @PerformedBy, @RejectionReason);

            INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
            VALUES ('CMS_Referrals', CAST(@NewReferralId AS VARCHAR(50)), 'REROUTE', @PerformedBy, @ReferralNumber);
        END
        ELSE
        BEGIN
            UPDATE [dbo].[CMS_Referrals]
            SET [Status] = @NewStatus
            WHERE [ReferralId] = @ReferralId;

            INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
            VALUES ('CMS_Referrals', CAST(@ReferralId AS VARCHAR(50)), @NewStatus, @PerformedBy, NULL);
        END

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Referral_GetByCase ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Referral_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    SELECT r.[ReferralId], r.[ReferralNumber], r.[CaseId], r.[ReferredTo],
           r.[Status], r.[RejectionReason], r.[ParentReferralId],
           p.[ReferralNumber] AS [ParentReferralNumber],
           r.[SlaDueAt], r.[Notes], r.[CreatedBy],
           u.[USERNAME] AS [CreatedByUsername], r.[CreatedAt], r.[RowVersion]
    FROM [dbo].[CMS_Referrals] r
    LEFT JOIN [dbo].[CMS_Referrals] p ON p.[ReferralId] = r.[ParentReferralId]
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = r.[CreatedBy]
    WHERE r.[CaseId] = @CaseId AND r.[IsActive] = 1
    ORDER BY r.[ReferralId];
END
GO

/* ---- sp_CMS_Referral_GetById (internal + reuse) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Referral_GetById]
    @ReferralId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT r.[ReferralId], r.[ReferralNumber], r.[CaseId], r.[ReferredTo],
           r.[Status], r.[RejectionReason], r.[ParentReferralId],
           p.[ReferralNumber] AS [ParentReferralNumber],
           r.[SlaDueAt], r.[Notes], r.[CreatedBy],
           u.[USERNAME] AS [CreatedByUsername], r.[CreatedAt], r.[RowVersion]
    FROM [dbo].[CMS_Referrals] r
    LEFT JOIN [dbo].[CMS_Referrals] p ON p.[ReferralId] = r.[ParentReferralId]
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = r.[CreatedBy]
    WHERE r.[ReferralId] = @ReferralId AND r.[IsActive] = 1;

    IF @@ROWCOUNT = 0
        THROW 50008, 'Referral not found.', 1;
END
GO

/* ---- sp_CMS_CaseComment_Add ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseComment_Add]
    @CaseId      INT,
    @CommentType VARCHAR(20) = 'NOTE',
    @Comment     NVARCHAR(2000),
    @CreatedBy   INT,
    @IpAddress   VARCHAR(45) = NULL,
    @NewCommentId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @CommentType = UPPER(LTRIM(RTRIM(ISNULL(@CommentType, 'NOTE'))));

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    IF @CommentType NOT IN ('NOTE', 'ALERT', 'HANDOVER')
        THROW 50010, 'Invalid comment type. Expected NOTE, ALERT or HANDOVER.', 1;

    IF NULLIF(LTRIM(RTRIM(@Comment)), '') IS NULL
        THROW 50010, 'Comment text is required.', 1;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO [dbo].[CMS_CaseComments]
            ([CaseId], [CommentType], [Comment], [CreatedBy], [IpAddress])
        VALUES
            (@CaseId, @CommentType, @Comment, @CreatedBy, @IpAddress);

        SET @NewCommentId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_CaseComments', CAST(@NewCommentId AS VARCHAR(50)), 'INSERT', @CreatedBy, @CommentType);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_CaseComment_GetByCase ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseComment_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    SELECT c.[CaseCommentId], c.[CaseId], c.[CommentType], c.[Comment],
           c.[CreatedBy], u.[USERNAME] AS [CreatedByUsername], c.[CreatedAt]
    FROM [dbo].[CMS_CaseComments] c
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = c.[CreatedBy]
    WHERE c.[CaseId] = @CaseId AND c.[IsActive] = 1
    ORDER BY c.[CaseCommentId] DESC;
END
GO
