/* ============================================================================
   35_WorkflowModule.sql
   Workflow step engine stored procedures (2026-11-07, DZ_ChildCareV3
   model): steps, per-step section permissions, step buttons, instances
   and the instance log.

   Two kinds of "actions" — do not mix them:
     CMS_WorkflowActions      field rules on load (Show/Hide/Disable/
                              Enable/Require/MakeOptional) — file 34.
     CMS_WorkflowStepActions  buttons under the form (SUBMIT/Approve/
                              Reject) that move the instance to the next
                              step and the next role — this file.

   Assignment: executing an action is checked in the service layer
   (the instance's CurrentRoleID must be one of the user's roles, or
   the user is admin) — the SPs below do not know the user.
   ============================================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_WorkflowStep_Save (one step, upsert) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowStep_Save]
    @WorkflowStepId   INT,
    @WorkflowId       INT,
    @StepCode         VARCHAR(100),
    @StepTitle        NVARCHAR(200),
    @ResponsibleRoleID INT = NULL,
    @ResponsibleWorkflowRoleID INT = NULL,
    @IsStart          BIT = 0,
    @IsEnd            BIT = 0,
    @SLA              INT = NULL,
    @DisplayOrder     INT = 0,
    @PerformedBy      INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Workflows] WHERE [WorkflowId] = @WorkflowId)
        THROW 50000, 'Workflow not found.', 1;
    IF @WorkflowStepId <> 0 AND NOT EXISTS (SELECT 1 FROM [dbo].[CMS_WorkflowSteps] WHERE [WorkflowStepId] = @WorkflowStepId AND [WorkflowId] = @WorkflowId)
        THROW 50000, 'Step not found.', 1;
    IF @StepCode IS NULL OR LTRIM(RTRIM(@StepCode)) = ''
        THROW 50000, 'Step code is required.', 1;
    IF EXISTS (SELECT 1 FROM [dbo].[CMS_WorkflowSteps]
               WHERE [WorkflowId] = @WorkflowId AND [StepCode] = @StepCode
                 AND [WorkflowStepId] <> @WorkflowStepId)
        THROW 50000, 'A step with this code already exists in the workflow.', 1;
    IF @ResponsibleRoleID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[ROLES] WHERE [ROLEID] = @ResponsibleRoleID)
        THROW 50000, 'Role not found.', 1;
    IF @ResponsibleWorkflowRoleID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[CMS_WorkflowRoles] WHERE [WorkflowRoleId] = @ResponsibleWorkflowRoleID AND [IsActive] = 1)
        THROW 50000, 'Workflow role not found.', 1;
    IF @SLA IS NOT NULL AND @SLA < 0
        THROW 50000, 'SLA days must be 0 or more.', 1;
    IF @DisplayOrder < 0
        THROW 50000, 'Display order must be 0 or more.', 1;

    DECLARE @IsNew BIT = CASE WHEN @WorkflowStepId = 0 THEN 1 ELSE 0 END;

    BEGIN TRY
        BEGIN TRAN;

        IF @WorkflowStepId = 0
        BEGIN
            INSERT INTO [dbo].[CMS_WorkflowSteps]
                ([WorkflowId], [StepCode], [StepTitle], [ResponsibleRoleID],
                 [ResponsibleWorkflowRoleID],
                 [IsStart], [IsEnd], [SLA], [DisplayOrder], [CreatedBy])
            VALUES (@WorkflowId, @StepCode, @StepTitle, @ResponsibleRoleID,
                    @ResponsibleWorkflowRoleID,
                    @IsStart, @IsEnd, @SLA, @DisplayOrder, @PerformedBy);
            SET @WorkflowStepId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            /* A NULL user role means "keep the stored one", not "clear
               it" (2026-11-10 fix): the Manage page no longer sends a
               user role, so an unconditional overwrite silently wiped
               the step's stored role on every edit — and instances on
               that step then lost their CurrentRoleID. */
            UPDATE [dbo].[CMS_WorkflowSteps]
            SET [StepCode] = @StepCode, [StepTitle] = @StepTitle,
                [ResponsibleRoleID] = ISNULL(@ResponsibleRoleID, [ResponsibleRoleID]),
                [ResponsibleWorkflowRoleID] = @ResponsibleWorkflowRoleID,
                [IsStart] = @IsStart, [IsEnd] = @IsEnd, [SLA] = @SLA,
                [DisplayOrder] = @DisplayOrder, [UpdatedAt] = SYSUTCDATETIME()
            WHERE [WorkflowStepId] = @WorkflowStepId;
        END

        /* Exactly one start step per workflow: marking this one the
           start unmarks the others. */
        IF @IsStart = 1
            UPDATE [dbo].[CMS_WorkflowSteps]
            SET [IsStart] = 0, [UpdatedAt] = SYSUTCDATETIME()
            WHERE [WorkflowId] = @WorkflowId AND [WorkflowStepId] <> @WorkflowStepId AND [IsStart] = 1;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy])
        VALUES ('CMS_WorkflowSteps', CAST(@WorkflowStepId AS VARCHAR(50)),
                CASE WHEN @IsNew = 1 THEN 'CREATE' ELSE 'UPDATE' END, @PerformedBy);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH

    SELECT @WorkflowStepId AS [WorkflowStepId];
END
GO

/* ---- sp_CMS_WorkflowStep_GetByWorkflow ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowStep_GetByWorkflow]
    @WorkflowId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.[WorkflowStepId], s.[WorkflowId], s.[StepCode], s.[StepTitle],
           s.[ResponsibleRoleID], r.[DESCRIPTION] AS [ResponsibleRoleName],
           s.[ResponsibleWorkflowRoleID], wr.[Title] AS [ResponsibleWorkflowRoleName],
           s.[IsStart], s.[IsEnd], s.[SLA], s.[DisplayOrder], s.[IsActive],
           s.[CreatedAt], s.[UpdatedAt],
           (SELECT COUNT(*) FROM [dbo].[CMS_WorkflowStepActions] a
             WHERE a.[WorkflowStepId] = s.[WorkflowStepId]) AS [StepActionCount],
           (SELECT COUNT(*) FROM [dbo].[CMS_WorkflowStepSections] ss
             WHERE ss.[WorkflowStepId] = s.[WorkflowStepId]) AS [StepSectionCount]
    FROM [dbo].[CMS_WorkflowSteps] s
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = s.[ResponsibleRoleID]
    LEFT JOIN [dbo].[CMS_WorkflowRoles] wr ON wr.[WorkflowRoleId] = s.[ResponsibleWorkflowRoleID]
    WHERE s.[WorkflowId] = @WorkflowId
    ORDER BY s.[DisplayOrder], s.[WorkflowStepId];
END
GO

/* ---- sp_CMS_WorkflowStep_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowStep_GetById]
    @WorkflowStepId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.[WorkflowStepId], s.[WorkflowId], s.[StepCode], s.[StepTitle],
           s.[ResponsibleRoleID], r.[DESCRIPTION] AS [ResponsibleRoleName],
           s.[ResponsibleWorkflowRoleID], wr.[Title] AS [ResponsibleWorkflowRoleName],
           s.[IsStart], s.[IsEnd], s.[SLA], s.[DisplayOrder], s.[IsActive],
           s.[CreatedAt], s.[UpdatedAt],
           (SELECT COUNT(*) FROM [dbo].[CMS_WorkflowStepActions] a
             WHERE a.[WorkflowStepId] = s.[WorkflowStepId]) AS [StepActionCount],
           (SELECT COUNT(*) FROM [dbo].[CMS_WorkflowStepSections] ss
             WHERE ss.[WorkflowStepId] = s.[WorkflowStepId]) AS [StepSectionCount]
    FROM [dbo].[CMS_WorkflowSteps] s
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = s.[ResponsibleRoleID]
    LEFT JOIN [dbo].[CMS_WorkflowRoles] wr ON wr.[WorkflowRoleId] = s.[ResponsibleWorkflowRoleID]
    WHERE s.[WorkflowStepId] = @WorkflowStepId;
END
GO

/* ---- sp_CMS_WorkflowStep_Delete ----
   A step a button points at cannot go: another step's action with
   NextStepCode = this step's code would dangle. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowStep_Delete]
    @WorkflowStepId INT,
    @PerformedBy    INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StepCode VARCHAR(100), @WorkflowId INT;
    SELECT @StepCode = [StepCode], @WorkflowId = [WorkflowId]
    FROM [dbo].[CMS_WorkflowSteps] WHERE [WorkflowStepId] = @WorkflowStepId;
    IF @StepCode IS NULL
        THROW 50000, 'Step not found.', 1;
    IF EXISTS (
        SELECT 1 FROM [dbo].[CMS_WorkflowStepActions] a
        INNER JOIN [dbo].[CMS_WorkflowSteps] s ON s.[WorkflowStepId] = a.[WorkflowStepId]
        WHERE s.[WorkflowId] = @WorkflowId AND a.[NextStepCode] = @StepCode
    )
        THROW 50000, 'This step is the next step of another step''s button and cannot be deleted.', 1;

    DELETE FROM [dbo].[CMS_WorkflowSteps] WHERE [WorkflowStepId] = @WorkflowStepId;

    INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy])
    VALUES ('CMS_WorkflowSteps', CAST(@WorkflowStepId AS VARCHAR(50)), 'DELETE', @PerformedBy);
END
GO

/* ---- sp_CMS_WorkflowStepSections_Save (wholesale replace per step) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowStepSections_Save]
    @WorkflowStepId INT,
    @SectionsJson   NVARCHAR(MAX) = NULL,
    @PerformedBy    INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WorkflowId INT, @FormId INT;
    SELECT @WorkflowId = w.[WorkflowId], @FormId = w.[FormId]
    FROM [dbo].[CMS_WorkflowSteps] s
    INNER JOIN [dbo].[CMS_Workflows] w ON w.[WorkflowId] = s.[WorkflowId]
    WHERE s.[WorkflowStepId] = @WorkflowStepId;
    IF @WorkflowId IS NULL
        THROW 50000, 'Step not found.', 1;
    IF @SectionsJson IS NOT NULL AND ISJSON(@SectionsJson) <> 1
        THROW 50000, 'Sections must be valid JSON.', 1;

    /* Section keys must be real sections of the workflow's form. */
    IF EXISTS (
        SELECT 1 FROM OPENJSON(@SectionsJson)
        WITH ([SectionKey] VARCHAR(100) '$.sectionKey') AS s
        WHERE s.[SectionKey] IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM [dbo].[CMS_DynamicFormFields] f
              WHERE f.[FormId] = @FormId AND f.[FieldType] = 'section'
                AND f.[FieldKey] = s.[SectionKey]
          )
    )
        THROW 50000, 'A section key is not a section of this form.', 1;

    BEGIN TRY
        BEGIN TRAN;

        DELETE FROM [dbo].[CMS_WorkflowStepSections] WHERE [WorkflowStepId] = @WorkflowStepId;

        INSERT INTO [dbo].[CMS_WorkflowStepSections]
            ([WorkflowStepId], [SectionKey], [IsVisible], [IsEnable], [DisplayOrder])
        SELECT @WorkflowStepId, s.[SectionKey], s.[IsVisible], s.[IsEnable], s.[DisplayOrder]
        FROM OPENJSON(@SectionsJson)
        WITH (
            [SectionKey]   VARCHAR(100) '$.sectionKey',
            [IsVisible]    BIT          '$.isVisible',
            [IsEnable]     BIT          '$.isEnable',
            [DisplayOrder] INT          '$.displayOrder'
        ) AS s
        WHERE s.[SectionKey] IS NOT NULL;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_WorkflowStepSections_GetByStep ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowStepSections_GetByStep]
    @WorkflowStepId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [WorkflowStepSectionId], [WorkflowStepId], [SectionKey],
           [IsVisible], [IsEnable], [DisplayOrder], [IsActive]
    FROM [dbo].[CMS_WorkflowStepSections]
    WHERE [WorkflowStepId] = @WorkflowStepId AND [IsActive] = 1
    ORDER BY [DisplayOrder], [WorkflowStepSectionId];
END
GO

/* ---- sp_CMS_WorkflowStepActions_Save (wholesale replace per step) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowStepActions_Save]
    @WorkflowStepId INT,
    @ActionsJson    NVARCHAR(MAX) = NULL,
    @PerformedBy    INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WorkflowId INT;
    SELECT @WorkflowId = [WorkflowId] FROM [dbo].[CMS_WorkflowSteps]
    WHERE [WorkflowStepId] = @WorkflowStepId;
    IF @WorkflowId IS NULL
        THROW 50000, 'Step not found.', 1;
    IF @ActionsJson IS NOT NULL AND ISJSON(@ActionsJson) <> 1
        THROW 50000, 'Actions must be valid JSON.', 1;

    /* Every button's next step must be a step of the same workflow,
       and a next role must be a real role. */
    IF EXISTS (
        SELECT 1 FROM OPENJSON(@ActionsJson)
        WITH ([NextStepCode] VARCHAR(100) '$.nextStepCode') AS a
        WHERE a.[NextStepCode] IS NOT NULL
          AND NOT EXISTS (
              SELECT 1 FROM [dbo].[CMS_WorkflowSteps] s
              WHERE s.[WorkflowId] = @WorkflowId AND s.[StepCode] = a.[NextStepCode]
          )
    )
        THROW 50000, 'A button''s next step is not a step of this workflow.', 1;
    IF EXISTS (
        SELECT 1 FROM OPENJSON(@ActionsJson)
        WITH ([NextRoleID] INT '$.nextRoleId') AS a
        WHERE a.[NextRoleID] IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM [dbo].[ROLES] WHERE [ROLEID] = a.[NextRoleID])
    )
        THROW 50000, 'A button''s next role is not a real role.', 1;
    IF EXISTS (
        SELECT 1 FROM OPENJSON(@ActionsJson)
        WITH ([NextWorkflowRoleID] INT '$.nextWorkflowRoleId') AS a
        WHERE a.[NextWorkflowRoleID] IS NOT NULL
          AND NOT EXISTS (SELECT 1 FROM [dbo].[CMS_WorkflowRoles] WHERE [WorkflowRoleId] = a.[NextWorkflowRoleID] AND [IsActive] = 1)
    )
        THROW 50000, 'A button''s next workflow role is not a real workflow role.', 1;

    BEGIN TRY
        BEGIN TRAN;

        /* Keep a stored button user role when the save carries none
           (2026-11-10 fix): the Manage page no longer sends one, so
           NULL here means "unchanged", not "clear" — the same rule as
           the step save. Buttons are matched by ActionCode. */
        SELECT [ActionCode], [NextRoleID]
        INTO #OldRoles
        FROM [dbo].[CMS_WorkflowStepActions]
        WHERE [WorkflowStepId] = @WorkflowStepId;

        DELETE FROM [dbo].[CMS_WorkflowStepActions] WHERE [WorkflowStepId] = @WorkflowStepId;

        INSERT INTO [dbo].[CMS_WorkflowStepActions]
            ([WorkflowStepId], [ActionCode], [ActionTitle], [NextStepCode],
             [NextAssignmentType], [NextRoleID], [NextWorkflowRoleID], [SaveOrMove], [IsSendEmail], [DisplayOrder])
        SELECT @WorkflowStepId, a.[ActionCode], a.[ActionTitle], a.[NextStepCode],
               ISNULL(a.[NextAssignmentType], 'Static'), ISNULL(a.[NextRoleID], o.[NextRoleID]), a.[NextWorkflowRoleID],
               ISNULL(a.[SaveOrMove], 1), ISNULL(a.[IsSendEmail], 0), a.[DisplayOrder]
        FROM OPENJSON(@ActionsJson)
        WITH (
            [ActionCode]         VARCHAR(100)  '$.actionCode',
            [ActionTitle]        NVARCHAR(200) '$.actionTitle',
            [NextStepCode]       VARCHAR(100)  '$.nextStepCode',
            [NextAssignmentType] VARCHAR(20)   '$.nextAssignmentType',
            [NextRoleID]         INT           '$.nextRoleId',
            [NextWorkflowRoleID] INT           '$.nextWorkflowRoleId',
            [SaveOrMove]         BIT           '$.saveOrMove',
            [IsSendEmail]        BIT           '$.isSendEmail',
            [DisplayOrder]       INT           '$.displayOrder'
        ) AS a
        LEFT JOIN #OldRoles o ON o.[ActionCode] = a.[ActionCode]
        WHERE a.[ActionCode] IS NOT NULL AND a.[NextStepCode] IS NOT NULL;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_WorkflowStepActions_GetByStep ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowStepActions_GetByStep]
    @WorkflowStepId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT a.[WorkflowStepActionId], a.[WorkflowStepId], a.[ActionCode], a.[ActionTitle],
           a.[NextStepCode], ns.[StepTitle] AS [NextStepTitle],
           a.[NextAssignmentType], a.[NextRoleID], r.[DESCRIPTION] AS [NextRoleName],
           a.[NextWorkflowRoleID], wr.[Title] AS [NextWorkflowRoleName],
           a.[SaveOrMove], a.[IsSendEmail], a.[DisplayOrder], a.[IsActive]
    FROM [dbo].[CMS_WorkflowStepActions] a
    INNER JOIN [dbo].[CMS_WorkflowSteps] s ON s.[WorkflowStepId] = a.[WorkflowStepId]
    LEFT JOIN [dbo].[CMS_WorkflowSteps] ns
        ON ns.[WorkflowId] = s.[WorkflowId] AND ns.[StepCode] = a.[NextStepCode]
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = a.[NextRoleID]
    LEFT JOIN [dbo].[CMS_WorkflowRoles] wr ON wr.[WorkflowRoleId] = a.[NextWorkflowRoleID]
    WHERE a.[WorkflowStepId] = @WorkflowStepId AND a.[IsActive] = 1
    ORDER BY a.[DisplayOrder], a.[WorkflowStepActionId];
END
GO

/* ---- sp_CMS_WorkflowInstance_Start ----
   One instance per (workflow, submission): a form entry travels its
   route once. The instance starts on the workflow's start step
   (IsStart = 1); its role and SLA come from that step.
   @SubmissionId may be NULL (instance-first start, 2026-11-10): the
   request is created by pressing Start and the entry is attached
   later via sp_CMS_WorkflowInstance_LinkSubmission.
   Instance-first dedupe (2026-11-10): IsStart = 1 AND SubmissionId
   NULL = empty draft. If the user already has one for this workflow,
   return it instead of creating a duplicate (Start, back, Start
   again). Oldest first: resume the first draft they abandoned.
   CurrentUserID (2026-11-10 fix): the user who started the request
   (@PerformedBy). It was never written before, so every instance
   and log row showed NULL. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowInstance_Start]
    @WorkflowId    INT,
    @SubmissionId  INT = NULL,
    @Comments      NVARCHAR(MAX) = NULL,
    @PerformedBy   INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FormId INT, @StartStepCode VARCHAR(100), @StartRoleID INT, @StartWorkflowRoleID INT, @StartSLA INT, @StartCount INT;
    SELECT @FormId = [FormId] FROM [dbo].[CMS_Workflows]
    WHERE [WorkflowId] = @WorkflowId AND [IsActive] = 1;
    IF @FormId IS NULL
        THROW 50000, 'Workflow not found or inactive.', 1;
    IF @SubmissionId IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_DynamicFormSubmissions]
                       WHERE [SubmissionId] = @SubmissionId AND [FormId] = @FormId)
            THROW 50000, 'Submission not found for this workflow''s form.', 1;
        IF EXISTS (SELECT 1 FROM [dbo].[CMS_WorkflowInstances]
                   WHERE [WorkflowId] = @WorkflowId AND [SubmissionId] = @SubmissionId)
            THROW 50000, 'This entry already has a workflow instance.', 1;
    END

    SELECT @StartCount = COUNT(*) FROM [dbo].[CMS_WorkflowSteps]
    WHERE [WorkflowId] = @WorkflowId AND [IsStart] = 1 AND [IsActive] = 1;
    IF @StartCount <> 1
        THROW 50000, 'The workflow must have exactly one start step.', 1;
    SELECT TOP 1 @StartStepCode = [StepCode], @StartRoleID = [ResponsibleRoleID], @StartWorkflowRoleID = [ResponsibleWorkflowRoleID], @StartSLA = [SLA]
    FROM [dbo].[CMS_WorkflowSteps]
    WHERE [WorkflowId] = @WorkflowId AND [IsStart] = 1 AND [IsActive] = 1;

    DECLARE @InstanceId INT;
    -- Empty-draft dedupe (see the header): one unfilled draft per
    -- user per workflow. Only when no entry is attached yet.
    IF @SubmissionId IS NULL
    BEGIN
        SELECT TOP 1 @InstanceId = [WorkflowInstanceId]
        FROM [dbo].[CMS_WorkflowInstances]
        WHERE [WorkflowId] = @WorkflowId AND [CreatedBy] = @PerformedBy
          AND [SubmissionId] IS NULL AND [CurrentStepCode] = @StartStepCode
        ORDER BY [WorkflowInstanceId] ASC;
        IF @InstanceId IS NOT NULL
        BEGIN
            SELECT @InstanceId AS [WorkflowInstanceId];
            RETURN;
        END
    END

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO [dbo].[CMS_WorkflowInstances]
            ([WorkflowId], [SubmissionId], [CurrentStepCode], [CurrentRoleID],
             [CurrentWorkflowRoleID], [CurrentUserID],
             [SLA_NoOfDays], [SLA_Date], [Stage], [Comments], [CreatedBy])
        VALUES (@WorkflowId, @SubmissionId, @StartStepCode, @StartRoleID,
                @StartWorkflowRoleID, @PerformedBy,
                @StartSLA,
                CASE WHEN @StartSLA IS NOT NULL
                     THEN DATEADD(DAY, @StartSLA, CAST(SYSUTCDATETIME() AS DATE)) ELSE NULL END,
                0, @Comments, @PerformedBy);
        SET @InstanceId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_WorkflowInstanceLogs]
            ([WorkflowInstanceId], [WorkflowId], [CurrentStepCode], [CurrentRoleID],
             [CurrentWorkflowRoleID], [CurrentUserID],
             [SLA_NoOfDays], [SLA_Date], [Stage], [Comments], [Status])
        VALUES (@InstanceId, @WorkflowId, @StartStepCode, @StartRoleID,
                @StartWorkflowRoleID, @PerformedBy,
                @StartSLA,
                CASE WHEN @StartSLA IS NOT NULL
                     THEN DATEADD(DAY, @StartSLA, CAST(SYSUTCDATETIME() AS DATE)) ELSE NULL END,
                0, @Comments, 'Started');

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH

    SELECT @InstanceId AS [WorkflowInstanceId];
END
GO

/* ---- sp_CMS_WorkflowInstance_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowInstance_GetById]
    @WorkflowInstanceId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT i.[WorkflowInstanceId], i.[WorkflowId], w.[WorkflowName], w.[WorkflowCode],
           w.[FormId], f.[FormKey], f.[Title] AS [FormTitle],
           i.[SubmissionId], i.[CurrentStepCode], s.[StepTitle] AS [CurrentStepTitle],
           CAST(ISNULL(s.[IsEnd], 0) AS BIT) AS [IsEndStep],
           i.[CurrentRoleID], r.[DESCRIPTION] AS [CurrentRoleName],
           i.[CurrentWorkflowRoleID], wr.[Title] AS [CurrentWorkflowRoleName],
           i.[CurrentUserID], i.[SLA_NoOfDays], i.[SLA_Date], i.[Stage], i.[Comments],
           i.[CreatedAt], i.[UpdatedAt]
    FROM [dbo].[CMS_WorkflowInstances] i
    INNER JOIN [dbo].[CMS_Workflows] w ON w.[WorkflowId] = i.[WorkflowId]
    INNER JOIN [dbo].[CMS_DynamicForms] f ON f.[FormId] = w.[FormId]
    LEFT JOIN [dbo].[CMS_WorkflowSteps] s
        ON s.[WorkflowId] = i.[WorkflowId] AND s.[StepCode] = i.[CurrentStepCode]
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = i.[CurrentRoleID]
    LEFT JOIN [dbo].[CMS_WorkflowRoles] wr ON wr.[WorkflowRoleId] = i.[CurrentWorkflowRoleID]
    WHERE i.[WorkflowInstanceId] = @WorkflowInstanceId;
END
GO

/* ---- sp_CMS_WorkflowInstance_GetMyTasks ----
   Pending work for a user: instances whose current role is one of
   the user's roles, or assigned to the user directly. Admins see
   everything pending. Finished (end-step) instances are not tasks.
   Empty drafts (IsStart = 1 AND SubmissionId NULL) are the creator's
   own unfinished request, not work for anyone else: they are hidden
   from other users' My Tasks. The creator still sees their own
   draft here and can resume it. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowInstance_GetMyTasks]
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsAdmin BIT = CASE WHEN EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERID] = @UserId AND [ADMIN] = 1)
                                THEN 1 ELSE 0 END;

    SELECT i.[WorkflowInstanceId], i.[WorkflowId], w.[WorkflowName], w.[WorkflowCode],
           w.[FormId], f.[FormKey], f.[Title] AS [FormTitle],
           i.[SubmissionId], i.[CurrentStepCode], s.[StepTitle] AS [CurrentStepTitle],
           CAST(ISNULL(s.[IsEnd], 0) AS BIT) AS [IsEndStep],
           i.[CurrentRoleID], r.[DESCRIPTION] AS [CurrentRoleName],
           i.[CurrentWorkflowRoleID], wr.[Title] AS [CurrentWorkflowRoleName],
           i.[CurrentUserID], i.[SLA_NoOfDays], i.[SLA_Date], i.[Stage], i.[Comments],
           i.[CreatedAt], i.[UpdatedAt]
    FROM [dbo].[CMS_WorkflowInstances] i
    INNER JOIN [dbo].[CMS_Workflows] w ON w.[WorkflowId] = i.[WorkflowId]
    INNER JOIN [dbo].[CMS_DynamicForms] f ON f.[FormId] = w.[FormId]
    LEFT JOIN [dbo].[CMS_WorkflowSteps] s
        ON s.[WorkflowId] = i.[WorkflowId] AND s.[StepCode] = i.[CurrentStepCode]
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = i.[CurrentRoleID]
    LEFT JOIN [dbo].[CMS_WorkflowRoles] wr ON wr.[WorkflowRoleId] = i.[CurrentWorkflowRoleID]
    WHERE ISNULL(s.[IsEnd], 0) = 0
      AND (
          @IsAdmin = 1
          OR i.[CurrentUserID] = @UserId
          OR i.[CurrentRoleID] IN (
              SELECT [ROLEID] FROM [dbo].[USER_ROLE]
              WHERE [USERID] = @UserId AND [ACTIVE] = 1)
          OR i.[CurrentWorkflowRoleID] IN (
              SELECT m.[WorkflowRoleId] FROM [dbo].[CMS_UserWorkflowRoles] m
              INNER JOIN [dbo].[CMS_WorkflowRoles] wfr
                  ON wfr.[WorkflowRoleId] = m.[WorkflowRoleId] AND wfr.[IsActive] = 1
              WHERE m.[UserId] = @UserId AND m.[IsActive] = 1)
      )
      -- Empty drafts are not other people's work (see the header).
      AND NOT (i.[SubmissionId] IS NULL AND ISNULL(s.[IsStart], 0) = 1
               AND ISNULL(i.[CreatedBy], -1) <> @UserId)
    ORDER BY CASE WHEN i.[SLA_Date] IS NULL THEN 1 ELSE 0 END, i.[SLA_Date], i.[CreatedAt] DESC;
END
GO

/* ---- sp_CMS_WorkflowInstance_GetUserAccess ----
   What the service needs for the assignment check: is the user an
   admin, which user roles do they hold, and which workflow roles
   (optional). Three result sets. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowInstance_GetUserAccess]
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CAST(CASE WHEN EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERID] = @UserId AND [ADMIN] = 1)
                     THEN 1 ELSE 0 END AS BIT) AS [IsAdmin];

    SELECT [ROLEID] AS [RoleId]
    FROM [dbo].[USER_ROLE]
    WHERE [USERID] = @UserId AND [ACTIVE] = 1;

    SELECT m.[WorkflowRoleId] AS [WorkflowRoleId]
    FROM [dbo].[CMS_UserWorkflowRoles] m
    INNER JOIN [dbo].[CMS_WorkflowRoles] wr
        ON wr.[WorkflowRoleId] = m.[WorkflowRoleId] AND wr.[IsActive] = 1
    WHERE m.[UserId] = @UserId AND m.[IsActive] = 1;
END
GO

/* ---- sp_CMS_WorkflowInstance_GetActions ----
   The buttons under the form at the instance's current step. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowInstance_GetActions]
    @WorkflowInstanceId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WorkflowId INT, @StepCode VARCHAR(100), @StepId INT;
    SELECT @WorkflowId = [WorkflowId], @StepCode = [CurrentStepCode]
    FROM [dbo].[CMS_WorkflowInstances] WHERE [WorkflowInstanceId] = @WorkflowInstanceId;
    IF @WorkflowId IS NULL
        THROW 50000, 'Instance not found.', 1;
    SELECT @StepId = [WorkflowStepId] FROM [dbo].[CMS_WorkflowSteps]
    WHERE [WorkflowId] = @WorkflowId AND [StepCode] = @StepCode;

    SELECT s.[WorkflowStepId], s.[StepCode], s.[StepTitle], s.[IsStart], s.[IsEnd]
    FROM [dbo].[CMS_WorkflowSteps] s
    WHERE s.[WorkflowStepId] = @StepId;

    SELECT a.[WorkflowStepActionId], a.[WorkflowStepId], a.[ActionCode], a.[ActionTitle],
           a.[NextStepCode], ns.[StepTitle] AS [NextStepTitle],
           a.[NextAssignmentType], a.[NextRoleID], r.[DESCRIPTION] AS [NextRoleName],
           a.[NextWorkflowRoleID], wr.[Title] AS [NextWorkflowRoleName],
           a.[SaveOrMove], a.[IsSendEmail], a.[DisplayOrder], a.[IsActive]
    FROM [dbo].[CMS_WorkflowStepActions] a
    LEFT JOIN [dbo].[CMS_WorkflowSteps] ns
        ON ns.[WorkflowId] = @WorkflowId AND ns.[StepCode] = a.[NextStepCode]
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = a.[NextRoleID]
    LEFT JOIN [dbo].[CMS_WorkflowRoles] wr ON wr.[WorkflowRoleId] = a.[NextWorkflowRoleID]
    WHERE a.[WorkflowStepId] = @StepId AND a.[IsActive] = 1
    ORDER BY a.[DisplayOrder], a.[WorkflowStepActionId];
END
GO

/* ---- sp_CMS_WorkflowInstance_ExecuteAction ----
   Press a button: the instance moves to the button's next step and
   next role, the SLA is set for the new step, and the move is logged.
   Next role: the button's role, else the next step's responsible role,
   else the role it already had — the same rule, separately, for the
   user role and the workflow role. No email is sent (IsSendEmail is
   only stored). CurrentUserID (2026-11-10 fix): the user who pressed
   the button (@PerformedBy) — the instance and the log row both
   record them, so the history shows who did each step. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowInstance_ExecuteAction]
    @WorkflowInstanceId INT,
    @ActionCode         VARCHAR(100),
    @Comments           NVARCHAR(MAX) = NULL,
    @PerformedBy        INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WorkflowId INT, @CurrentStepCode VARCHAR(100), @CurrentRoleID INT, @CurrentWorkflowRoleID INT, @Stage INT;
    SELECT @WorkflowId = [WorkflowId], @CurrentStepCode = [CurrentStepCode],
           @CurrentRoleID = [CurrentRoleID], @CurrentWorkflowRoleID = [CurrentWorkflowRoleID], @Stage = [Stage]
    FROM [dbo].[CMS_WorkflowInstances] WHERE [WorkflowInstanceId] = @WorkflowInstanceId;
    IF @WorkflowId IS NULL
        THROW 50000, 'Instance not found.', 1;

    DECLARE @StepId INT, @IsEnd BIT;
    SELECT @StepId = [WorkflowStepId], @IsEnd = [IsEnd]
    FROM [dbo].[CMS_WorkflowSteps]
    WHERE [WorkflowId] = @WorkflowId AND [StepCode] = @CurrentStepCode;
    IF @StepId IS NULL
        THROW 50000, 'The instance''s current step no longer exists.', 1;
    IF @IsEnd = 1
        THROW 50000, 'This request is already at an end step.', 1;

    DECLARE @ActionId INT, @NextStepCode VARCHAR(100), @NextRoleID INT, @NextWorkflowRoleID INT;
    SELECT @ActionId = [WorkflowStepActionId], @NextStepCode = [NextStepCode],
           @NextRoleID = [NextRoleID], @NextWorkflowRoleID = [NextWorkflowRoleID]
    FROM [dbo].[CMS_WorkflowStepActions]
    WHERE [WorkflowStepId] = @StepId AND [ActionCode] = @ActionCode AND [IsActive] = 1;
    IF @ActionId IS NULL
        THROW 50000, 'This button is not available at the current step.', 1;

    DECLARE @NextStepId INT, @NextStepSLA INT, @NextStepRoleID INT, @NextStepWorkflowRoleID INT;
    SELECT @NextStepId = [WorkflowStepId], @NextStepSLA = [SLA], @NextStepRoleID = [ResponsibleRoleID],
           @NextStepWorkflowRoleID = [ResponsibleWorkflowRoleID]
    FROM [dbo].[CMS_WorkflowSteps]
    WHERE [WorkflowId] = @WorkflowId AND [StepCode] = @NextStepCode;
    IF @NextStepId IS NULL
        THROW 50000, 'The button''s next step no longer exists.', 1;

    DECLARE @NewRoleID INT = ISNULL(@NextRoleID, ISNULL(@NextStepRoleID, @CurrentRoleID));
    DECLARE @NewWorkflowRoleID INT = ISNULL(@NextWorkflowRoleID, ISNULL(@NextStepWorkflowRoleID, @CurrentWorkflowRoleID));
    DECLARE @NewSLADate DATETIME2 = CASE WHEN @NextStepSLA IS NOT NULL
        THEN DATEADD(DAY, @NextStepSLA, CAST(SYSUTCDATETIME() AS DATE)) ELSE NULL END;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE [dbo].[CMS_WorkflowInstances]
        SET [CurrentStepCode] = @NextStepCode,
            [CurrentRoleID] = @NewRoleID,
            [CurrentWorkflowRoleID] = @NewWorkflowRoleID,
            [CurrentUserID] = @PerformedBy,
            [SLA_NoOfDays] = @NextStepSLA,
            [SLA_Date] = @NewSLADate,
            [Comments] = ISNULL(@Comments, [Comments]),
            [UpdatedAt] = SYSUTCDATETIME()
        WHERE [WorkflowInstanceId] = @WorkflowInstanceId;

        INSERT INTO [dbo].[CMS_WorkflowInstanceLogs]
            ([WorkflowInstanceId], [WorkflowId], [CurrentStepCode], [CurrentRoleID],
             [CurrentWorkflowRoleID], [CurrentUserID],
             [SLA_NoOfDays], [SLA_Date], [Stage], [Comments], [Status])
        VALUES (@WorkflowInstanceId, @WorkflowId, @NextStepCode, @NewRoleID,
                @NewWorkflowRoleID, @PerformedBy,
                @NextStepSLA, @NewSLADate, @Stage, @Comments, @ActionCode);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH

    EXEC [dbo].[sp_CMS_WorkflowInstance_GetById] @WorkflowInstanceId = @WorkflowInstanceId;
END
GO

/* ---- sp_CMS_WorkflowInstance_GetLog (newest first) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowInstance_GetLog]
    @WorkflowInstanceId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT l.[WorkflowInstanceLogId], l.[WorkflowInstanceId],
           l.[CurrentStepCode], s.[StepTitle] AS [CurrentStepTitle],
           l.[CurrentRoleID], r.[DESCRIPTION] AS [CurrentRoleName],
           l.[CurrentWorkflowRoleID], wr.[Title] AS [CurrentWorkflowRoleName],
           l.[CurrentUserID], l.[SLA_NoOfDays], l.[SLA_Date], l.[Stage],
           l.[Comments], l.[LogDate], l.[Status]
    FROM [dbo].[CMS_WorkflowInstanceLogs] l
    INNER JOIN [dbo].[CMS_WorkflowInstances] i ON i.[WorkflowInstanceId] = l.[WorkflowInstanceId]
    LEFT JOIN [dbo].[CMS_WorkflowSteps] s
        ON s.[WorkflowId] = l.[WorkflowId] AND s.[StepCode] = l.[CurrentStepCode]
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = l.[CurrentRoleID]
    LEFT JOIN [dbo].[CMS_WorkflowRoles] wr ON wr.[WorkflowRoleId] = l.[CurrentWorkflowRoleID]
    WHERE l.[WorkflowInstanceId] = @WorkflowInstanceId
    ORDER BY l.[LogDate] DESC, l.[WorkflowInstanceLogId] DESC;
END
GO

/* ---- sp_CMS_WorkflowInstance_LinkSubmission ----
   Instance-first start (2026-11-10): attach the form entry that was
   created after the request. The instance must not have an entry yet,
   and the entry must belong to the workflow's form and to no other
   request. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowInstance_LinkSubmission]
    @WorkflowInstanceId INT,
    @SubmissionId       INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WorkflowId INT, @FormId INT, @ExistingSubmissionId INT;
    SELECT @WorkflowId = [WorkflowId], @ExistingSubmissionId = [SubmissionId]
    FROM [dbo].[CMS_WorkflowInstances]
    WHERE [WorkflowInstanceId] = @WorkflowInstanceId;
    IF @WorkflowId IS NULL
        THROW 50000, 'Workflow instance not found.', 1;
    IF @ExistingSubmissionId IS NOT NULL
        THROW 50000, 'This request already has a form entry.', 1;
    SELECT @FormId = [FormId] FROM [dbo].[CMS_Workflows]
    WHERE [WorkflowId] = @WorkflowId AND [IsActive] = 1;
    IF @FormId IS NULL
        THROW 50000, 'Workflow not found or inactive.', 1;
    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_DynamicFormSubmissions]
                   WHERE [SubmissionId] = @SubmissionId AND [FormId] = @FormId)
        THROW 50000, 'Submission not found for this workflow''s form.', 1;
    IF EXISTS (SELECT 1 FROM [dbo].[CMS_WorkflowInstances]
               WHERE [SubmissionId] = @SubmissionId AND [WorkflowInstanceId] <> @WorkflowInstanceId)
        THROW 50000, 'This entry already belongs to another request.', 1;

    UPDATE [dbo].[CMS_WorkflowInstances]
    SET [SubmissionId] = @SubmissionId, [UpdatedAt] = SYSUTCDATETIME()
    WHERE [WorkflowInstanceId] = @WorkflowInstanceId;

    EXEC [dbo].[sp_CMS_WorkflowInstance_GetById] @WorkflowInstanceId = @WorkflowInstanceId;
END
GO
