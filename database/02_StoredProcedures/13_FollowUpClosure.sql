/* ============================================================================
   AKA-CMS — Sprint 7 (Module 6: Follow-Up, LTFU, Closure, Supervision)
   Stored procedures. One proc per repository method; TRY/CATCH +
   transactions + CMS_AuditLogs on every write.

   Error-number contract (project-wide):
     50005 - row-version mismatch (optimistic concurrency)
     50008 - entity not found
     50009 - domain validation failure (400)
     50010 - invalid domain value (400)
     50011 - duplicate/conflict (409)
   ============================================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_FollowUp_Schedule ----
   Schedules a follow-up against a case (S32). The case must be active
   and not closed; scheduling against IN_TREATMENT is what moves it into
   the follow-up track (the ScheduleFollowUp workflow transition is
   applied best-effort by the Application layer). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_FollowUp_Schedule]
    @CaseId INT,
    @ScheduledDate DATETIME2,
    @FollowUpType VARCHAR(40),
    @AssignedToUserId INT = NULL,
    @Notes NVARCHAR(2000) = NULL,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewFollowUpId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @CaseStatus VARCHAR(30);
        SELECT @CaseStatus = [Status]
        FROM [dbo].[CMS_Cases]
        WHERE [CaseId] = @CaseId AND [IsActive] = 1;

        IF @CaseStatus IS NULL
            THROW 50008, 'Case not found.', 1;
        IF @CaseStatus NOT IN ('IN_TREATMENT', 'INTERVENTION', 'MONITORING', 'FOLLOW_UP')
            THROW 50009, 'Follow-ups can only be scheduled for cases in treatment or follow-up.', 1;
        IF @ScheduledDate IS NULL
            THROW 50009, 'ScheduledDate is required.', 1;
        IF @FollowUpType NOT IN ('SCHEDULED', 'QUARTERLY_RESCREEN', 'RE_ENGAGEMENT')
            THROW 50010, 'FollowUpType must be SCHEDULED, QUARTERLY_RESCREEN or RE_ENGAGEMENT.', 1;

        INSERT INTO [dbo].[CMS_FollowUps]
            ([CaseId], [ScheduledDate], [FollowUpType], [AssignedToUserId],
             [Notes], [Status], [IsActive], [CreatedBy], [IpAddress])
        VALUES
            (@CaseId, @ScheduledDate, @FollowUpType, @AssignedToUserId,
             @Notes, 'SCHEDULED', 1, @CreatedBy, @IpAddress);

        SET @NewFollowUpId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_FollowUps', CAST(@NewFollowUpId AS VARCHAR(50)), 'INSERT', @CreatedBy,
                @FollowUpType + ' follow-up scheduled for case ' + CAST(@CaseId AS VARCHAR(20)));

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_FollowUp_RecordOutcome ----
   Records the outcome of a scheduled follow-up (S33 Follow-Up Attended?
   Yes -> S33a continue care; No -> missed, feeds the LTFU counter that
   S33b evaluates). Returns the case id and its current RowVersion so the
   Application layer can attempt the matching workflow transition
   (best-effort, never rolled back). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_FollowUp_RecordOutcome]
    @FollowUpId INT,
    @Outcome VARCHAR(20),
    @OutcomeNotes NVARCHAR(2000) = NULL,
    @ActualDate DATETIME2 = NULL,
    @RowVersion VARBINARY(8),
    @PerformedBy INT,
    @IpAddress VARCHAR(50),
    @CaseId INT OUTPUT,
    @CaseRowVersion VARBINARY(8) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF @Outcome NOT IN ('COMPLETED', 'MISSED', 'CANCELLED')
            THROW 50010, 'Outcome must be COMPLETED, MISSED or CANCELLED.', 1;

        DECLARE @DbRowVersion VARBINARY(8);
        DECLARE @DbStatus VARCHAR(20);
        SELECT @CaseId = [CaseId], @DbStatus = [Status], @DbRowVersion = [RowVersion]
        FROM [dbo].[CMS_FollowUps]
        WHERE [FollowUpId] = @FollowUpId AND [IsActive] = 1;

        IF @CaseId IS NULL
            THROW 50008, 'Follow-up not found.', 1;
        IF @DbStatus <> 'SCHEDULED'
            THROW 50009, 'Outcome can only be recorded on a SCHEDULED follow-up.', 1;
        IF @DbRowVersion <> @RowVersion
            THROW 50005, 'The follow-up was modified by another user.', 1;

        SET @ActualDate = ISNULL(@ActualDate, SYSUTCDATETIME());

        UPDATE [dbo].[CMS_FollowUps]
        SET [Status] = @Outcome,
            [OutcomeNotes] = @OutcomeNotes,
            [ActualDate] = @ActualDate,
            [ModifiedBy] = @PerformedBy,
            [ModifiedAt] = SYSUTCDATETIME(),
            [IpAddress] = @IpAddress
        WHERE [FollowUpId] = @FollowUpId;

        IF @Outcome = 'COMPLETED'
        BEGIN
            UPDATE [dbo].[CMS_LostToFollowUps]
            SET [MissedCount] = 0,
                [LastContactDate] = @ActualDate,
                [ModifiedBy] = @PerformedBy,
                [ModifiedAt] = SYSUTCDATETIME(),
                [IpAddress] = @IpAddress
            WHERE [CaseId] = @CaseId AND [Status] <> 'LTFU' AND [IsActive] = 1;
        END
        ELSE IF @Outcome = 'MISSED'
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_LostToFollowUps]
                           WHERE [CaseId] = @CaseId AND [IsActive] = 1)
            BEGIN
                INSERT INTO [dbo].[CMS_LostToFollowUps]
                    ([CaseId], [MissedCount], [Status], [IsActive], [CreatedBy], [IpAddress])
                VALUES (@CaseId, 1, 'AT_RISK', 1, @PerformedBy, @IpAddress);
            END
            ELSE
            BEGIN
                UPDATE [dbo].[CMS_LostToFollowUps]
                SET [MissedCount] = CASE WHEN [Status] = 'LTFU' THEN [MissedCount]
                                        ELSE [MissedCount] + 1 END,
                    [ModifiedBy] = @PerformedBy,
                    [ModifiedAt] = SYSUTCDATETIME(),
                    [IpAddress] = @IpAddress
                WHERE [CaseId] = @CaseId AND [IsActive] = 1;
            END
        END

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_FollowUps', CAST(@FollowUpId AS VARCHAR(50)), 'UPDATE', @PerformedBy,
                'Outcome -> ' + @Outcome + ' for case ' + CAST(@CaseId AS VARCHAR(20)));

        SELECT @CaseRowVersion = [RowVersion]
        FROM [dbo].[CMS_Cases]
        WHERE [CaseId] = @CaseId;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_LostToFollowUp_Flag ----
   Evaluates the consecutive-missed counter against the threshold in
   CMS_SystemSettings and declares LTFU when reached (S33b). Fully
   idempotent: re-running declares nothing twice, and a case already in
   LTFU is returned as a no-op. On declaration, an Immediate Alert style
   notification is queued for the SUPERVISOR role (S33c). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_LostToFollowUp_Flag]
    @CaseId INT,
    @PerformedBy INT,
    @IpAddress VARCHAR(50),
    @Declared BIT OUTPUT,
    @LtfuId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases]
                       WHERE [CaseId] = @CaseId AND [IsActive] = 1)
            THROW 50008, 'Case not found.', 1;

        DECLARE @Threshold INT;
        SELECT @Threshold = TRY_CAST([SettingValue] AS INT)
        FROM [dbo].[CMS_SystemSettings]
        WHERE [SettingKey] = 'Ltfu.MissedFollowUpThreshold';
        SET @Threshold = ISNULL(NULLIF(@Threshold, 0), 1);

        SELECT @LtfuId = [LtfuId]
        FROM [dbo].[CMS_LostToFollowUps]
        WHERE [CaseId] = @CaseId AND [IsActive] = 1;

        IF @LtfuId IS NULL
        BEGIN
            INSERT INTO [dbo].[CMS_LostToFollowUps]
                ([CaseId], [MissedCount], [Status], [IsActive], [CreatedBy], [IpAddress])
            VALUES (@CaseId, 0, 'AT_RISK', 1, @PerformedBy, @IpAddress);
            SET @LtfuId = SCOPE_IDENTITY();
        END

        DECLARE @Status VARCHAR(20);
        DECLARE @MissedCount INT;
        SELECT @Status = [Status], @MissedCount = [MissedCount]
        FROM [dbo].[CMS_LostToFollowUps]
        WHERE [LtfuId] = @LtfuId;

        SET @Declared = 0;

        IF @Status <> 'LTFU' AND @MissedCount >= @Threshold
        BEGIN
            UPDATE [dbo].[CMS_LostToFollowUps]
            SET [Status] = 'LTFU',
                [LtfuDeclaredDate] = SYSUTCDATETIME(),
                [ModifiedBy] = @PerformedBy,
                [ModifiedAt] = SYSUTCDATETIME(),
                [IpAddress] = @IpAddress
            WHERE [LtfuId] = @LtfuId;

            INSERT INTO [dbo].[CMS_Notifications]
                ([RecipientRole], [Title], [Body], [RelatedCaseId],
                 [RelatedEntity], [RelatedEntityId], [IsRead], [IsActive])
            VALUES
                ('SUPERVISOR',
                 N'Lost-to-follow-up declared',
                 N'Case ' + CAST(@CaseId AS NVARCHAR(20))
                   + N' reached the missed-follow-up threshold (' + CAST(@Threshold AS NVARCHAR(10))
                   + N') and is now marked Lost-to-Follow-Up. Supervisor review and re-engagement required.',
                 @CaseId, 'LTFU', @LtfuId, 0, 1);

            INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
            VALUES ('CMS_LostToFollowUps', CAST(@LtfuId AS VARCHAR(50)), 'UPDATE', @PerformedBy,
                    'LTFU declared for case ' + CAST(@CaseId AS VARCHAR(20))
                    + ' (missed=' + CAST(@MissedCount AS VARCHAR(10))
                    + ', threshold=' + CAST(@Threshold AS VARCHAR(10)) + ')');

            SET @Declared = 1;
        END

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_LostToFollowUp_ReEngage ----
   Records re-engagement for an LTFU case (S33d). Resets the missed
   counter; the Application layer applies the ReEngage workflow
   transition (LTFU -> FOLLOW_UP) best-effort afterwards. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_LostToFollowUp_ReEngage]
    @CaseId INT,
    @ReEngagementNotes NVARCHAR(2000),
    @PerformedBy INT,
    @IpAddress VARCHAR(50),
    @CaseRowVersion VARBINARY(8) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @LtfuId INT;
        DECLARE @Status VARCHAR(20);
        SELECT @LtfuId = [LtfuId], @Status = [Status]
        FROM [dbo].[CMS_LostToFollowUps]
        WHERE [CaseId] = @CaseId AND [IsActive] = 1;

        IF @LtfuId IS NULL
            THROW 50008, 'No LTFU tracking record found for this case.', 1;
        IF @Status <> 'LTFU'
            THROW 50009, 'Only a case currently marked LTFU can be re-engaged.', 1;
        IF @ReEngagementNotes IS NULL OR LTRIM(RTRIM(@ReEngagementNotes)) = ''
            THROW 50009, 'ReEngagementNotes are required.', 1;

        UPDATE [dbo].[CMS_LostToFollowUps]
        SET [Status] = 'RE_ENGAGED',
            [ReEngagementNotes] = @ReEngagementNotes,
            [MissedCount] = 0,
            [LastContactDate] = SYSUTCDATETIME(),
            [ModifiedBy] = @PerformedBy,
            [ModifiedAt] = SYSUTCDATETIME(),
            [IpAddress] = @IpAddress
        WHERE [LtfuId] = @LtfuId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_LostToFollowUps', CAST(@LtfuId AS VARCHAR(50)), 'UPDATE', @PerformedBy,
                'Re-engaged case ' + CAST(@CaseId AS VARCHAR(20)));

        SELECT @CaseRowVersion = [RowVersion]
        FROM [dbo].[CMS_Cases]
        WHERE [CaseId] = @CaseId;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_CaseClosure_Request ----
   Step 1 of the two-step closure: a case worker requests closure. The
   S34a Symptom Remission gate is captured on the request; approval is a
   separate, supervisor-gated step. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseClosure_Request]
    @CaseId INT,
    @ClosureReason VARCHAR(40),
    @SymptomRemission BIT,
    @ClosureSummary NVARCHAR(MAX) = NULL,
    @RequestedByUserId INT,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewClosureId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @CaseStatus VARCHAR(30);
        SELECT @CaseStatus = [Status]
        FROM [dbo].[CMS_Cases]
        WHERE [CaseId] = @CaseId AND [IsActive] = 1;

        IF @CaseStatus IS NULL
            THROW 50008, 'Case not found.', 1;
        IF @CaseStatus = 'CLOSED'
            THROW 50009, 'The case is already closed.', 1;
        IF @ClosureReason NOT IN ('TREATMENT_COMPLETE', 'SYMPTOM_REMISSION', 'LTFU',
                                  'NO_CONSENT', 'REFERRAL_COMPLETE', 'OTHER')
            THROW 50010, 'ClosureReason is not a recognized value.', 1;
        IF EXISTS (SELECT 1 FROM [dbo].[CMS_CaseClosures]
                   WHERE [CaseId] = @CaseId AND [ApprovalStatus] = 'PENDING' AND [IsActive] = 1)
            THROW 50011, 'A closure request is already pending for this case.', 1;

        INSERT INTO [dbo].[CMS_CaseClosures]
            ([CaseId], [ClosureReason], [SymptomRemission], [ClosureSummary],
             [ApprovalStatus], [RequestedByUserId], [IsActive], [CreatedBy], [IpAddress])
        VALUES
            (@CaseId, @ClosureReason, @SymptomRemission, @ClosureSummary,
             'PENDING', @RequestedByUserId, 1, @CreatedBy, @IpAddress);

        SET @NewClosureId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_CaseClosures', CAST(@NewClosureId AS VARCHAR(50)), 'INSERT', @CreatedBy,
                'Closure requested for case ' + CAST(@CaseId AS VARCHAR(20))
                + ' (reason=' + @ClosureReason + ')');

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_CaseClosure_Approve ----
   Step 2 of the two-step closure (S34b Clinical Supervisor Approval).
   Enforces the S34a Symptom Remission gate: approval is rejected when
   the request does not confirm remission. The workflow Close transition
   itself is applied best-effort by the Application layer, so a case in
   an unclosable state fails loudly with a note instead of silently
   blocking. Rejected requests return 400 on re-approval; a fresh
   request may be raised afterwards (reopened cases may carry several
   closure rows). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseClosure_Approve]
    @ClosureId INT,
    @Approve BIT,
    @RejectionReason NVARCHAR(1000) = NULL,
    @ApprovedByUserId INT,
    @RowVersion VARBINARY(8),
    @PerformedBy INT,
    @IpAddress VARCHAR(50),
    @CaseId INT OUTPUT,
    @CaseRowVersion VARBINARY(8) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @DbRowVersion VARBINARY(8);
        DECLARE @ApprovalStatus VARCHAR(20);
        DECLARE @SymptomRemission BIT;
        SELECT @CaseId = [CaseId], @ApprovalStatus = [ApprovalStatus],
               @SymptomRemission = [SymptomRemission], @DbRowVersion = [RowVersion]
        FROM [dbo].[CMS_CaseClosures]
        WHERE [ClosureId] = @ClosureId AND [IsActive] = 1;

        IF @CaseId IS NULL
            THROW 50008, 'Closure request not found.', 1;
        IF @ApprovalStatus <> 'PENDING'
            THROW 50009, 'Only a PENDING closure request can be decided.', 1;
        IF @DbRowVersion <> @RowVersion
            THROW 50005, 'The closure request was modified by another user.', 1;

        IF @Approve = 1
        BEGIN
            IF @SymptomRemission = 0
                THROW 50009, 'Case closure requires confirmed symptom remission (S34a gate).', 1;

            UPDATE [dbo].[CMS_CaseClosures]
            SET [ApprovalStatus] = 'APPROVED',
                [ApprovedByUserId] = @ApprovedByUserId,
                [ApprovedAt] = SYSUTCDATETIME(),
                [ModifiedBy] = @PerformedBy,
                [ModifiedAt] = SYSUTCDATETIME(),
                [IpAddress] = @IpAddress
            WHERE [ClosureId] = @ClosureId;
        END
        ELSE
        BEGIN
            IF @RejectionReason IS NULL OR LTRIM(RTRIM(@RejectionReason)) = ''
                THROW 50009, 'RejectionReason is required when rejecting a closure request.', 1;

            UPDATE [dbo].[CMS_CaseClosures]
            SET [ApprovalStatus] = 'REJECTED',
                [ApprovedByUserId] = @ApprovedByUserId,
                [ApprovedAt] = SYSUTCDATETIME(),
                [RejectionReason] = @RejectionReason,
                [ModifiedBy] = @PerformedBy,
                [ModifiedAt] = SYSUTCDATETIME(),
                [IpAddress] = @IpAddress
            WHERE [ClosureId] = @ClosureId;
        END

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_CaseClosures', CAST(@ClosureId AS VARCHAR(50)), 'UPDATE', @PerformedBy,
                CASE WHEN @Approve = 1 THEN 'Closure APPROVED' ELSE 'Closure REJECTED' END
                + ' for case ' + CAST(@CaseId AS VARCHAR(20)));

        SELECT @CaseRowVersion = [RowVersion]
        FROM [dbo].[CMS_Cases]
        WHERE [CaseId] = @CaseId;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_SupervisionLog_Create ----
   Records an ongoing clinical/case supervision review against a case
   (S37). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_SupervisionLog_Create]
    @CaseId INT,
    @SupervisorUserId INT,
    @ReviewDate DATETIME2,
    @Findings NVARCHAR(MAX),
    @ActionItems NVARCHAR(MAX) = NULL,
    @Rating VARCHAR(30) = NULL,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewLogId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases]
                       WHERE [CaseId] = @CaseId AND [IsActive] = 1)
            THROW 50008, 'Case not found.', 1;
        IF @Findings IS NULL OR LTRIM(RTRIM(@Findings)) = ''
            THROW 50009, 'Findings are required.', 1;
        IF @ReviewDate IS NULL
            THROW 50009, 'ReviewDate is required.', 1;
        IF @Rating IS NOT NULL
           AND @Rating NOT IN ('SATISFACTORY', 'NEEDS_IMPROVEMENT', 'UNSATISFACTORY')
            THROW 50010, 'Rating must be SATISFACTORY, NEEDS_IMPROVEMENT or UNSATISFACTORY.', 1;

        INSERT INTO [dbo].[CMS_SupervisionLogs]
            ([CaseId], [SupervisorUserId], [ReviewDate], [Findings],
             [ActionItems], [Rating], [IsActive], [CreatedBy], [IpAddress])
        VALUES
            (@CaseId, @SupervisorUserId, @ReviewDate, @Findings,
             @ActionItems, @Rating, 1, @CreatedBy, @IpAddress);

        SET @NewLogId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_SupervisionLogs', CAST(@NewLogId AS VARCHAR(50)), 'INSERT', @CreatedBy,
                'Supervision review logged for case ' + CAST(@CaseId AS VARCHAR(20)));

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- Read procs (case-scoped lists) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_FollowUps_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT [FollowUpId], [CaseId], [ScheduledDate], [ActualDate], [FollowUpType],
           [AssignedToUserId], [Notes], [Status], [OutcomeNotes], [RowVersion],
           [IsActive], [CreatedBy], [CreatedAt]
    FROM [dbo].[CMS_FollowUps]
    WHERE [CaseId] = @CaseId AND [IsActive] = 1
    ORDER BY [ScheduledDate];
END
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_LostToFollowUp_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT [LtfuId], [CaseId], [MissedCount], [LastContactDate], [LtfuDeclaredDate],
           [Status], [ReEngagementNotes], [RowVersion], [IsActive], [CreatedBy], [CreatedAt]
    FROM [dbo].[CMS_LostToFollowUps]
    WHERE [CaseId] = @CaseId AND [IsActive] = 1;
END
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseClosures_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT [ClosureId], [CaseId], [ClosureReason], [SymptomRemission], [ClosureSummary],
           [ApprovalStatus], [RequestedByUserId], [RequestedAt], [ApprovedByUserId],
           [ApprovedAt], [RejectionReason], [RowVersion], [IsActive], [CreatedBy], [CreatedAt]
    FROM [dbo].[CMS_CaseClosures]
    WHERE [CaseId] = @CaseId AND [IsActive] = 1
    ORDER BY [RequestedAt] DESC;
END
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_SupervisionLogs_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT [SupervisionLogId], [CaseId], [SupervisorUserId], [ReviewDate], [Findings],
           [ActionItems], [Rating], [RowVersion], [IsActive], [CreatedBy], [CreatedAt]
    FROM [dbo].[CMS_SupervisionLogs]
    WHERE [CaseId] = @CaseId AND [IsActive] = 1
    ORDER BY [ReviewDate] DESC;
END
GO

/* ---- sp_CMS_FollowUp_GetDue ----
   FollowUpDueService backing: generates the due list from
   CMS_SystemSettings risk-based frequencies. A case is due when the
   days since last completed contact reach the frequency of its
   PriorityLevel and no future SCHEDULED follow-up exists. Only cases
   in follow-up-relevant states are considered. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_FollowUp_GetDue]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FreqHigh INT = ISNULL(TRY_CAST(
        (SELECT [SettingValue] FROM [dbo].[CMS_SystemSettings]
         WHERE [SettingKey] = 'FollowUp.FrequencyDays.High') AS INT), 7);
    DECLARE @FreqModerate INT = ISNULL(TRY_CAST(
        (SELECT [SettingValue] FROM [dbo].[CMS_SystemSettings]
         WHERE [SettingKey] = 'FollowUp.FrequencyDays.Moderate') AS INT), 14);
    DECLARE @FreqLow INT = ISNULL(TRY_CAST(
        (SELECT [SettingValue] FROM [dbo].[CMS_SystemSettings]
         WHERE [SettingKey] = 'FollowUp.FrequencyDays.Low') AS INT), 30);

    SELECT
        c.[CaseId],
        c.[CaseNumber],
        c.[PriorityLevel],
        c.[Status] AS [CaseStatus],
        ISNULL(lc.[LastContact], c.[CreatedAt]) AS [LastContactDate],
        DATEDIFF(DAY, ISNULL(lc.[LastContact], c.[CreatedAt]), SYSUTCDATETIME()) AS [DaysSinceContact],
        CASE c.[PriorityLevel]
            WHEN 'High' THEN @FreqHigh
            WHEN 'Moderate' THEN @FreqModerate
            ELSE @FreqLow
        END AS [FrequencyDays]
    FROM [dbo].[CMS_Cases] c
    OUTER APPLY (
        SELECT MAX([ActualDate]) AS [LastContact]
        FROM [dbo].[CMS_FollowUps] f
        WHERE f.[CaseId] = c.[CaseId] AND f.[IsActive] = 1 AND f.[Status] = 'COMPLETED'
    ) lc
    WHERE c.[IsActive] = 1
      AND c.[Status] IN ('FOLLOW_UP', 'IN_TREATMENT', 'MONITORING')
      AND NOT EXISTS (
          SELECT 1 FROM [dbo].[CMS_FollowUps] f2
          WHERE f2.[CaseId] = c.[CaseId] AND f2.[IsActive] = 1
            AND f2.[Status] = 'SCHEDULED'
            AND CAST(f2.[ScheduledDate] AS DATE) >= CAST(SYSUTCDATETIME() AS DATE))
      AND DATEDIFF(DAY, ISNULL(lc.[LastContact], c.[CreatedAt]), SYSUTCDATETIME())
          >= CASE c.[PriorityLevel]
                 WHEN 'High' THEN @FreqHigh
                 WHEN 'Moderate' THEN @FreqModerate
                 ELSE @FreqLow
             END
    ORDER BY [DaysSinceContact] DESC;
END
GO
