/* ============================================================
   AKA-CMS — Sprint 4 stored procedures (10)
   Module 2: Helpline & Crisis Management.

   Emergency path coverage (wireframing PDF / workflow sheet):
     sp_CMS_HelplineCall_Log
         Logs a helpline call. When crisis indicators resolve to
         one or more crisis types (S7 "Emergency Presentation? =
         Yes"), the same transaction ALSO creates the crisis event
         (S7b activate crisis protocol) and the Immediate Alert
         notification row (S7a).
     sp_CMS_CrisisEvent_Trigger
         Manual trigger (TriggerSource = MANUAL or SCREENING_SEVERE):
         creates the event + fires the Immediate Alert notification
         to the SUPERVISOR role. Case routing (EMERGENCY) is done by
         the Application layer via the workflow engine — never
         rolled back with the event.
     sp_CMS_CrisisEvent_UpdateStatus
         Status -> STABILIZED maps to the S7g "Stabilized? = Yes"
         branch (case returns to clinical pathway via the Stabilize
         transition); CONTINUE_CARE maps to S7i. RowVersion-checked.
     sp_CMS_SafetyPlan_Create / GetByCase
         Safety plan (Proposal Phase D action).

   Error codes: 50005 = concurrency (stale RowVersion),
                50008 = not found, 50010 = invalid value.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_HelplineCall_Log ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_HelplineCall_Log]
    @CallerName           NVARCHAR(200) = NULL,
    @CallerPhone          VARCHAR(30)   = NULL,
    @CaseId               INT           = NULL,
    @CrisisIndicatorsJson NVARCHAR(MAX) = NULL,
    @CrisisTypeCodes      VARCHAR(200)  = NULL, -- CSV resolved by CrisisDetectionService
    @CrisisSeverity       VARCHAR(10)   = NULL, -- CRITICAL / HIGH / MODERATE
    @CallNotes            NVARCHAR(MAX) = NULL,
    @HandledBy            INT,
    @IpAddress            VARCHAR(45)   = NULL,
    @NewCallId            INT OUTPUT,
    @NewCrisisEventId     INT OUTPUT,
    @NewNotificationId    INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @CaseId IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    SET @NewCrisisEventId = NULL;
    SET @NewNotificationId = NULL;

    DECLARE @HasCrisis BIT = 0;
    IF @CrisisTypeCodes IS NOT NULL AND LTRIM(RTRIM(@CrisisTypeCodes)) <> ''
        SET @HasCrisis = 1;

    IF @HasCrisis = 1
    BEGIN
        /* every resolved code must exist in the catalog */
        IF EXISTS (
            SELECT 1 FROM STRING_SPLIT(@CrisisTypeCodes, ',') s
            WHERE LTRIM(RTRIM(s.[value])) <> ''
              AND NOT EXISTS (
                    SELECT 1 FROM [dbo].[CMS_CrisisTypes] t
                    WHERE t.[CrisisTypeCode] = UPPER(LTRIM(RTRIM(s.[value])))
                      AND t.[IsActive] = 1)
        )
            THROW 50010, 'Invalid crisis type code.', 1;

        SET @CrisisSeverity = UPPER(LTRIM(RTRIM(ISNULL(@CrisisSeverity, 'HIGH'))));
        IF @CrisisSeverity NOT IN ('CRITICAL', 'HIGH', 'MODERATE')
            THROW 50010, 'Invalid crisis severity. Expected CRITICAL, HIGH or MODERATE.', 1;
    END

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO [dbo].[CMS_HelplineCalls]
            ([CallerName], [CallerPhone], [CaseId], [CrisisIndicatorsJson],
             [CrisisTypeCodes], [CrisisSeverity], [CallNotes], [HandledBy], [IpAddress])
        VALUES
            (@CallerName, @CallerPhone, @CaseId, @CrisisIndicatorsJson,
             NULLIF(LTRIM(RTRIM(@CrisisTypeCodes)), ''), @CrisisSeverity, @CallNotes, @HandledBy, @IpAddress);

        SET @NewCallId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_HelplineCalls', CAST(@NewCallId AS VARCHAR(50)), 'INSERT', @HandledBy,
                ISNULL(@CallerName, 'anonymous'));

        /* S7 = Yes: create crisis event + Immediate Alert (S7a/S7b) */
        IF @HasCrisis = 1 AND @CaseId IS NOT NULL
        BEGIN
            DECLARE @PrimaryCode VARCHAR(10);
            SELECT TOP (1) @PrimaryCode = UPPER(LTRIM(RTRIM(s.[value])))
            FROM STRING_SPLIT(@CrisisTypeCodes, ',') s
            WHERE LTRIM(RTRIM(s.[value])) <> '';

            INSERT INTO [dbo].[CMS_CrisisEvents]
                ([CaseId], [CrisisTypeCode], [Severity], [TriggerSource], [Status], [Notes], [CreatedBy], [IpAddress])
            VALUES
                (@CaseId, @PrimaryCode, @CrisisSeverity, 'HELPLINE_CALL', 'OPEN',
                 'Auto-created from helpline call #' + CAST(@NewCallId AS VARCHAR(20))
                 + ' (indicators: ' + ISNULL(@CrisisTypeCodes, '') + ').',
                 @HandledBy, @IpAddress);

            SET @NewCrisisEventId = SCOPE_IDENTITY();

            INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
            VALUES ('CMS_CrisisEvents', CAST(@NewCrisisEventId AS VARCHAR(50)), 'INSERT', @HandledBy,
                    'TriggerSource=HELPLINE_CALL Severity=' + @CrisisSeverity);

            DECLARE @CaseNumber VARCHAR(30);
            SELECT @CaseNumber = [CaseNumber] FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId;

            INSERT INTO [dbo].[CMS_Notifications]
                ([RecipientRole], [Title], [Body], [RelatedCaseId], [RelatedEntity], [RelatedEntityId])
            VALUES
                ('SUPERVISOR',
                 'Immediate Alert: crisis event on case ' + ISNULL(@CaseNumber, CAST(@CaseId AS VARCHAR(20))),
                 'Crisis protocol activated (S7a). Type(s): ' + ISNULL(@CrisisTypeCodes, '')
                 + '. Severity: ' + @CrisisSeverity
                 + '. Source: helpline call #' + CAST(@NewCallId AS VARCHAR(20)) + '.',
                 @CaseId, 'CRISIS_EVENT', @NewCrisisEventId);

            SET @NewNotificationId = SCOPE_IDENTITY();
        END

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_CrisisEvent_Trigger ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CrisisEvent_Trigger]
    @CaseId          INT,
    @CrisisTypeCode  VARCHAR(10),
    @Severity        VARCHAR(10),
    @TriggerSource   VARCHAR(30), -- HELPLINE_CALL / SCREENING_SEVERE / MANUAL
    @Notes           NVARCHAR(MAX) = NULL,
    @PerformedBy     INT,
    @IpAddress       VARCHAR(45)   = NULL,
    @NewEventId      INT OUTPUT,
    @NewNotificationId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    SET @CrisisTypeCode = UPPER(LTRIM(RTRIM(@CrisisTypeCode)));
    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_CrisisTypes]
                   WHERE [CrisisTypeCode] = @CrisisTypeCode AND [IsActive] = 1)
        THROW 50010, 'Invalid crisis type code.', 1;

    SET @Severity = UPPER(LTRIM(RTRIM(@Severity)));
    IF @Severity NOT IN ('CRITICAL', 'HIGH', 'MODERATE')
        THROW 50010, 'Invalid severity. Expected CRITICAL, HIGH or MODERATE.', 1;

    SET @TriggerSource = UPPER(LTRIM(RTRIM(@TriggerSource)));
    IF @TriggerSource NOT IN ('HELPLINE_CALL', 'SCREENING_SEVERE', 'MANUAL')
        THROW 50010, 'Invalid trigger source. Expected HELPLINE_CALL, SCREENING_SEVERE or MANUAL.', 1;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO [dbo].[CMS_CrisisEvents]
            ([CaseId], [CrisisTypeCode], [Severity], [TriggerSource], [Status], [Notes], [CreatedBy], [IpAddress])
        VALUES
            (@CaseId, @CrisisTypeCode, @Severity, @TriggerSource, 'OPEN', @Notes, @PerformedBy, @IpAddress);

        SET @NewEventId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_CrisisEvents', CAST(@NewEventId AS VARCHAR(50)), 'INSERT', @PerformedBy,
                'TriggerSource=' + @TriggerSource + ' Severity=' + @Severity);

        /* S7a Immediate Alert to the supervisor role */
        DECLARE @CaseNumber VARCHAR(30);
        SELECT @CaseNumber = [CaseNumber] FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId;

        INSERT INTO [dbo].[CMS_Notifications]
            ([RecipientRole], [Title], [Body], [RelatedCaseId], [RelatedEntity], [RelatedEntityId])
        VALUES
            ('SUPERVISOR',
             'Immediate Alert: crisis event on case ' + ISNULL(@CaseNumber, CAST(@CaseId AS VARCHAR(20))),
             'Crisis protocol activated (S7a). Type: ' + @CrisisTypeCode
             + '. Severity: ' + @Severity
             + '. Source: ' + @TriggerSource + '.',
             @CaseId, 'CRISIS_EVENT', @NewEventId);

        SET @NewNotificationId = SCOPE_IDENTITY();

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_CrisisEvent_UpdateStatus ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CrisisEvent_UpdateStatus]
    @CrisisEventId  INT,
    @NewStatus      VARCHAR(20), -- OPEN / STABILIZED / ESCALATED / CONTINUE_CARE
    @RowVersion     BINARY(8),
    @PerformedBy    INT,
    @IpAddress      VARCHAR(45) = NULL,
    @CaseId         INT OUTPUT,
    @CaseRowVersion BINARY(8) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @NewStatus = UPPER(LTRIM(RTRIM(@NewStatus)));
    IF @NewStatus NOT IN ('OPEN', 'STABILIZED', 'ESCALATED', 'CONTINUE_CARE')
        THROW 50010, 'Invalid status. Expected OPEN, STABILIZED, ESCALATED or CONTINUE_CARE.', 1;

    DECLARE @Current VARBINARY(8);
    SELECT @Current = [RowVersion], @CaseId = [CaseId]
    FROM [dbo].[CMS_CrisisEvents]
    WHERE [CrisisEventId] = @CrisisEventId AND [IsActive] = 1;

    IF @Current IS NULL
        THROW 50008, 'Crisis event not found.', 1;

    IF @Current <> @RowVersion
        THROW 50005, 'The crisis event was modified by another user.', 1;

    SELECT @CaseRowVersion = [RowVersion]
    FROM [dbo].[CMS_Cases]
    WHERE [CaseId] = @CaseId;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE [dbo].[CMS_CrisisEvents]
        SET [Status] = @NewStatus,
            [UpdatedAt] = SYSUTCDATETIME(),
            [IpAddress] = @IpAddress
        WHERE [CrisisEventId] = @CrisisEventId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_CrisisEvents', CAST(@CrisisEventId AS VARCHAR(50)), 'UPDATE_STATUS', @PerformedBy,
                'Status=' + @NewStatus);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_CrisisEvent_GetByCase ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CrisisEvent_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    SELECT e.[CrisisEventId], e.[CaseId], e.[CrisisTypeCode], t.[DisplayName] AS [CrisisTypeName],
           e.[Severity], e.[TriggerSource], e.[Status], e.[Notes],
           e.[CreatedBy], u.[USERNAME] AS [CreatedByUsername],
           e.[CreatedAt], e.[UpdatedAt], e.[RowVersion]
    FROM [dbo].[CMS_CrisisEvents] e
    INNER JOIN [dbo].[CMS_CrisisTypes] t ON t.[CrisisTypeCode] = e.[CrisisTypeCode]
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = e.[CreatedBy]
    WHERE e.[CaseId] = @CaseId AND e.[IsActive] = 1
    ORDER BY e.[CreatedAt] DESC;
END
GO

/* ---- sp_CMS_CrisisEvent_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CrisisEvent_GetById]
    @CrisisEventId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_CrisisEvents]
                   WHERE [CrisisEventId] = @CrisisEventId AND [IsActive] = 1)
        THROW 50008, 'Crisis event not found.', 1;

    SELECT e.[CrisisEventId], e.[CaseId], e.[CrisisTypeCode], t.[DisplayName] AS [CrisisTypeName],
           e.[Severity], e.[TriggerSource], e.[Status], e.[Notes],
           e.[CreatedBy], u.[USERNAME] AS [CreatedByUsername],
           e.[CreatedAt], e.[UpdatedAt], e.[RowVersion]
    FROM [dbo].[CMS_CrisisEvents] e
    INNER JOIN [dbo].[CMS_CrisisTypes] t ON t.[CrisisTypeCode] = e.[CrisisTypeCode]
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = e.[CreatedBy]
    WHERE e.[CrisisEventId] = @CrisisEventId;
END
GO

/* ---- sp_CMS_CrisisType_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CrisisType_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [CrisisTypeCode], [DisplayName], [DefaultSeverity], [Description], [SortOrder]
    FROM [dbo].[CMS_CrisisTypes]
    WHERE [IsActive] = 1
    ORDER BY [SortOrder];
END
GO

/* ---- sp_CMS_SafetyPlan_Create ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_SafetyPlan_Create]
    @CaseId             INT,
    @WarningSigns       NVARCHAR(MAX),
    @CopingStrategies   NVARCHAR(MAX),
    @SupportContactsJson NVARCHAR(MAX) = NULL,
    @CreatedBy          INT,
    @IpAddress          VARCHAR(45)   = NULL,
    @NewPlanId          INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    IF @WarningSigns IS NULL OR LTRIM(RTRIM(@WarningSigns)) = ''
        THROW 50010, 'WarningSigns is required.', 1;

    IF @CopingStrategies IS NULL OR LTRIM(RTRIM(@CopingStrategies)) = ''
        THROW 50010, 'CopingStrategies is required.', 1;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO [dbo].[CMS_SafetyPlans]
            ([CaseId], [WarningSigns], [CopingStrategies], [SupportContactsJson], [CreatedBy], [IpAddress])
        VALUES
            (@CaseId, @WarningSigns, @CopingStrategies, @SupportContactsJson, @CreatedBy, @IpAddress);

        SET @NewPlanId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_SafetyPlans', CAST(@NewPlanId AS VARCHAR(50)), 'INSERT', @CreatedBy,
                'CaseId=' + CAST(@CaseId AS VARCHAR(20)));

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_SafetyPlan_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_SafetyPlan_GetById]
    @SafetyPlanId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_SafetyPlans]
                   WHERE [SafetyPlanId] = @SafetyPlanId AND [IsActive] = 1)
        THROW 50008, 'Safety plan not found.', 1;

    SELECT p.[SafetyPlanId], p.[CaseId], p.[WarningSigns], p.[CopingStrategies],
           p.[SupportContactsJson], p.[CreatedBy], u.[USERNAME] AS [CreatedByUsername],
           p.[CreatedAt], p.[RowVersion]
    FROM [dbo].[CMS_SafetyPlans] p
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = p.[CreatedBy]
    WHERE p.[SafetyPlanId] = @SafetyPlanId;
END
GO

/* ---- sp_CMS_SafetyPlan_GetByCase ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_SafetyPlan_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    SELECT p.[SafetyPlanId], p.[CaseId], p.[WarningSigns], p.[CopingStrategies],
           p.[SupportContactsJson], p.[CreatedBy], u.[USERNAME] AS [CreatedByUsername],
           p.[CreatedAt], p.[RowVersion]
    FROM [dbo].[CMS_SafetyPlans] p
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = p.[CreatedBy]
    WHERE p.[CaseId] = @CaseId AND p.[IsActive] = 1
    ORDER BY p.[CreatedAt] DESC;
END
GO

/* ---- sp_CMS_HelplineCall_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_HelplineCall_GetById]
    @HelplineCallId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_HelplineCalls]
                   WHERE [HelplineCallId] = @HelplineCallId AND [IsActive] = 1)
        THROW 50008, 'Helpline call not found.', 1;

    SELECT c.[HelplineCallId], c.[CallerName], c.[CallerPhone], c.[CaseId],
           c.[CrisisIndicatorsJson], c.[CrisisTypeCodes], c.[CrisisSeverity],
           c.[CallNotes], c.[HandledBy], u.[USERNAME] AS [HandledByUsername],
           c.[CallStartedAt], c.[CreatedAt], c.[RowVersion]
    FROM [dbo].[CMS_HelplineCalls] c
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = c.[HandledBy]
    WHERE c.[HelplineCallId] = @HelplineCallId;
END
GO

/* ---- sp_CMS_HelplineCall_GetList ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_HelplineCall_GetList]
    @CaseId INT = NULL,
    @Top    INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    IF @Top IS NULL OR @Top < 1 SET @Top = 50;
    IF @Top > 200 SET @Top = 200;

    SELECT TOP (@Top)
           c.[HelplineCallId], c.[CallerName], c.[CallerPhone], c.[CaseId],
           c.[CrisisIndicatorsJson], c.[CrisisTypeCodes], c.[CrisisSeverity],
           c.[CallNotes], c.[HandledBy], u.[USERNAME] AS [HandledByUsername],
           c.[CallStartedAt], c.[CreatedAt], c.[RowVersion]
    FROM [dbo].[CMS_HelplineCalls] c
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = c.[HandledBy]
    WHERE c.[IsActive] = 1
      AND (@CaseId IS NULL OR c.[CaseId] = @CaseId)
    ORDER BY c.[CreatedAt] DESC;
END
GO
