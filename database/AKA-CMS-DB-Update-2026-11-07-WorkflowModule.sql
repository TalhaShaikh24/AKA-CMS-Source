/* ============================================================================
   AKA-CMS-DB-Update-2026-11-07-WorkflowModule.sql
   Workflow step engine (2026-11-07) — ONE file, run in order:
     1. 47_CMS_WorkflowModule.sql  (5 new tables + WorkflowCode + permissions)
     2. 35_WorkflowModule.sql     (step / step-section / step-action /
                                    instance stored procedures)
     3. 34_Workflows.sql          (UPDATED procedures only: Save with
                                    WorkflowCode, GetById/GetAll with
                                    WorkflowCode, GetSectionsByForm
                                    step-aware via @InstanceId)
   Idempotent: safe to re-run. After running: restart the API, then
   log out and back in (new permissions load at startup, JWT claims
   at login).
   ============================================================================ */

/* ============================================================================
   47_CMS_WorkflowModule.sql
   Workflow step engine (2026-11-07, user go-ahead on the 2026-11-07
   understanding PDF): the DZ_ChildCareV3 model (workflow CI) on top of
   the form-section workflow (46).

   Old model -> new tables:
     tbl_WorkFlowSteps                  -> CMS_WorkflowSteps
     tbl_Workflow_StepSectionPermission -> CMS_WorkflowStepSections
                                          (per-step section permissions;
                                          CMS_WorkflowSections stays the
                                          per-workflow default and is NOT
                                          touched — a step's rows override
                                          it when an instance is at that
                                          step)
     tbl_WorkFlowStep_Actions           -> CMS_WorkflowStepActions
                                          (buttons under the form — NOT
                                          the field-level CMS_WorkflowActions)
     tbl_WorkFlow_Instance              -> CMS_WorkflowInstances
     tbl_WorkFlow_Instance_Log          -> CMS_WorkflowInstanceLogs

   Also: CMS_Workflows gains WorkflowCode (client-facing code like
   'CI', unique where not null). DynamicFunctionKey / ReturnUrl /
   NextStage are NOT carried over (empty in the old sample data).
   ============================================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- CMS_Workflows.WorkflowCode ---- */
IF COL_LENGTH('dbo.CMS_Workflows', 'WorkflowCode') IS NULL
BEGIN
    ALTER TABLE [dbo].[CMS_Workflows]
        ADD [WorkflowCode] VARCHAR(50) NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM [sys].[indexes] WHERE [name] = 'UQ_CMS_Workflows_WorkflowCode' AND [object_id] = OBJECT_ID('dbo.CMS_Workflows'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [UQ_CMS_Workflows_WorkflowCode]
        ON [dbo].[CMS_Workflows] ([WorkflowCode])
        WHERE [WorkflowCode] IS NOT NULL;
END
GO

/* ---- CMS_WorkflowSteps ---- */
IF COL_LENGTH('dbo.CMS_WorkflowSteps', 'WorkflowStepId') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_WorkflowSteps] (
        [WorkflowStepId]    INT IDENTITY(1,1) NOT NULL CONSTRAINT [PK_CMS_WorkflowSteps] PRIMARY KEY,
        [WorkflowId]        INT NOT NULL CONSTRAINT [FK_CMS_WorkflowSteps_Workflow] FOREIGN KEY
                                REFERENCES [dbo].[CMS_Workflows] ([WorkflowId]) ON DELETE CASCADE,
        [StepCode]          VARCHAR(100) NOT NULL,
        [StepTitle]         NVARCHAR(200) NOT NULL,
        [ResponsibleRoleID] INT NULL,
        [IsStart]           BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowSteps_IsStart] DEFAULT (0),
        [IsEnd]             BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowSteps_IsEnd] DEFAULT (0),
        [SLA]               INT NULL,
        [DisplayOrder]      INT NOT NULL CONSTRAINT [DF_CMS_WorkflowSteps_DisplayOrder] DEFAULT (0),
        [IsActive]          BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowSteps_IsActive] DEFAULT (1),
        [CreatedBy]         INT NULL,
        [CreatedAt]         DATETIME2 NOT NULL CONSTRAINT [DF_CMS_WorkflowSteps_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [UpdatedAt]         DATETIME2 NULL,
        CONSTRAINT [UQ_CMS_WorkflowSteps_Workflow_StepCode] UNIQUE ([WorkflowId], [StepCode])
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_WorkflowSteps_Workflow] ON [dbo].[CMS_WorkflowSteps] ([WorkflowId], [DisplayOrder]);
END
GO

/* ---- CMS_WorkflowStepSections ---- */
IF COL_LENGTH('dbo.CMS_WorkflowStepSections', 'WorkflowStepSectionId') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_WorkflowStepSections] (
        [WorkflowStepSectionId] INT IDENTITY(1,1) NOT NULL CONSTRAINT [PK_CMS_WorkflowStepSections] PRIMARY KEY,
        [WorkflowStepId]        INT NOT NULL CONSTRAINT [FK_CMS_WorkflowStepSections_Step] FOREIGN KEY
                                    REFERENCES [dbo].[CMS_WorkflowSteps] ([WorkflowStepId]) ON DELETE CASCADE,
        [SectionKey]            VARCHAR(100) NOT NULL,
        [IsVisible]             BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowStepSections_IsVisible] DEFAULT (1),
        [IsEnable]              BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowStepSections_IsEnable] DEFAULT (1),
        [DisplayOrder]          INT NOT NULL CONSTRAINT [DF_CMS_WorkflowStepSections_DisplayOrder] DEFAULT (0),
        [IsActive]              BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowStepSections_IsActive] DEFAULT (1),
        [CreatedAt]             DATETIME2 NOT NULL CONSTRAINT [DF_CMS_WorkflowStepSections_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [UQ_CMS_WorkflowStepSections_Step_Section] UNIQUE ([WorkflowStepId], [SectionKey])
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_WorkflowStepSections_Step] ON [dbo].[CMS_WorkflowStepSections] ([WorkflowStepId], [DisplayOrder]);
END
GO

/* ---- CMS_WorkflowStepActions (buttons under the form) ---- */
IF COL_LENGTH('dbo.CMS_WorkflowStepActions', 'WorkflowStepActionId') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_WorkflowStepActions] (
        [WorkflowStepActionId] INT IDENTITY(1,1) NOT NULL CONSTRAINT [PK_CMS_WorkflowStepActions] PRIMARY KEY,
        [WorkflowStepId]       INT NOT NULL CONSTRAINT [FK_CMS_WorkflowStepActions_Step] FOREIGN KEY
                                   REFERENCES [dbo].[CMS_WorkflowSteps] ([WorkflowStepId]) ON DELETE CASCADE,
        [ActionCode]           VARCHAR(100) NOT NULL,
        [ActionTitle]          NVARCHAR(200) NOT NULL,
        [NextStepCode]         VARCHAR(100) NOT NULL,
        [NextAssignmentType]   VARCHAR(20) NOT NULL CONSTRAINT [DF_CMS_WorkflowStepActions_NextAssignmentType] DEFAULT ('Static'),
        [NextRoleID]           INT NULL,
        [SaveOrMove]           BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowStepActions_SaveOrMove] DEFAULT (1),
        [IsSendEmail]          BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowStepActions_IsSendEmail] DEFAULT (0),
        [DisplayOrder]         INT NOT NULL CONSTRAINT [DF_CMS_WorkflowStepActions_DisplayOrder] DEFAULT (0),
        [IsActive]             BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowStepActions_IsActive] DEFAULT (1),
        [CreatedAt]            DATETIME2 NOT NULL CONSTRAINT [DF_CMS_WorkflowStepActions_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [UQ_CMS_WorkflowStepActions_Step_Code] UNIQUE ([WorkflowStepId], [ActionCode])
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_WorkflowStepActions_Step] ON [dbo].[CMS_WorkflowStepActions] ([WorkflowStepId], [DisplayOrder]);
END
GO

/* ---- CMS_WorkflowInstances (one live request per form entry) ---- */
IF COL_LENGTH('dbo.CMS_WorkflowInstances', 'WorkflowInstanceId') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_WorkflowInstances] (
        [WorkflowInstanceId] INT IDENTITY(1,1) NOT NULL CONSTRAINT [PK_CMS_WorkflowInstances] PRIMARY KEY,
        [WorkflowId]         INT NOT NULL CONSTRAINT [FK_CMS_WorkflowInstances_Workflow] FOREIGN KEY
                                 REFERENCES [dbo].[CMS_Workflows] ([WorkflowId]),
        [SubmissionId]       INT NULL CONSTRAINT [FK_CMS_WorkflowInstances_Submission] FOREIGN KEY
                                 REFERENCES [dbo].[CMS_DynamicFormSubmissions] ([SubmissionId]),
        [CurrentStepCode]    VARCHAR(100) NOT NULL,
        [CurrentRoleID]      INT NULL,
        [CurrentUserID]      INT NULL,
        [SLA_NoOfDays]       INT NULL,
        [SLA_Date]           DATETIME2 NULL,
        [Stage]              INT NULL,
        [Comments]           NVARCHAR(MAX) NULL,
        [CreatedBy]          INT NULL,
        [CreatedAt]          DATETIME2 NOT NULL CONSTRAINT [DF_CMS_WorkflowInstances_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [UpdatedAt]          DATETIME2 NULL,
        CONSTRAINT [UQ_CMS_WorkflowInstances_Workflow_Submission] UNIQUE ([WorkflowId], [SubmissionId])
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_WorkflowInstances_CurrentRole] ON [dbo].[CMS_WorkflowInstances] ([CurrentRoleID], [CurrentStepCode]);
    CREATE NONCLUSTERED INDEX [IX_CMS_WorkflowInstances_Submission] ON [dbo].[CMS_WorkflowInstances] ([SubmissionId]);
END
GO

/* ---- CMS_WorkflowInstanceLogs (one row per move) ---- */
IF COL_LENGTH('dbo.CMS_WorkflowInstanceLogs', 'WorkflowInstanceLogId') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_WorkflowInstanceLogs] (
        [WorkflowInstanceLogId] INT IDENTITY(1,1) NOT NULL CONSTRAINT [PK_CMS_WorkflowInstanceLogs] PRIMARY KEY,
        [WorkflowInstanceId]    INT NOT NULL CONSTRAINT [FK_CMS_WorkflowInstanceLogs_Instance] FOREIGN KEY
                                    REFERENCES [dbo].[CMS_WorkflowInstances] ([WorkflowInstanceId]) ON DELETE CASCADE,
        [WorkflowId]            INT NOT NULL,
        [CurrentStepCode]       VARCHAR(100) NOT NULL,
        [CurrentRoleID]         INT NULL,
        [CurrentUserID]         INT NULL,
        [SLA_NoOfDays]          INT NULL,
        [SLA_Date]              DATETIME2 NULL,
        [Stage]                 INT NULL,
        [Comments]              NVARCHAR(MAX) NULL,
        [LogDate]               DATETIME2 NOT NULL CONSTRAINT [DF_CMS_WorkflowInstanceLogs_LogDate] DEFAULT (SYSUTCDATETIME()),
        [Status]                NVARCHAR(100) NULL
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_WorkflowInstanceLogs_Instance] ON [dbo].[CMS_WorkflowInstanceLogs] ([WorkflowInstanceId], [LogDate] DESC);
END
GO

/* ---- Permission catalog entries (dynamic IDs, Facilities pattern) ---- */
INSERT INTO [dbo].[AllCONTROLLERS]
    ([ID], [CONTROLLERNAME], [RETURNTYPE], [ATTRIBUTES], [ACTION])
SELECT v.[ID], v.[CONTROLLERNAME], NULL, NULL, v.[ACTION]
FROM
(
    SELECT defs.[CONTROLLERNAME],
           defs.[ACTION],
           (SELECT ISNULL(MAX([ID]), 90051)
            FROM [dbo].[AllCONTROLLERS] WITH (UPDLOCK, HOLDLOCK)
            WHERE [ID] >= 90000)
           + ROW_NUMBER() OVER (ORDER BY defs.[CONTROLLERNAME], defs.[ACTION]) AS [ID]
    FROM (VALUES
        ('WorkflowSteps', 'Read'),
        ('WorkflowSteps', 'Write'),
        ('WorkflowInstances', 'Read'),
        ('WorkflowInstances', 'Write')
    ) AS defs ([CONTROLLERNAME], [ACTION])
) AS v
WHERE NOT EXISTS
(
    SELECT 1
    FROM [dbo].[AllCONTROLLERS] AS t
    WHERE t.[CONTROLLERNAME] = v.[CONTROLLERNAME]
      AND t.[ACTION] = v.[ACTION]
);
GO

/* ---- Grants: admin + supervisor full, frontline roles read ----
   Note: executing a step action is gated by WorkflowInstances:Read
   PLUS the assignment check (the instance's current role must be one
   of the user's roles, or the user is admin) — the role check, not
   the Write permission, is what lets a frontline user act on their
   own task. */
DECLARE @StepRead INT, @StepWrite INT, @InstRead INT, @InstWrite INT;
SELECT @StepRead = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'WorkflowSteps' AND [ACTION] = 'Read';
SELECT @StepWrite = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'WorkflowSteps' AND [ACTION] = 'Write';
SELECT @InstRead = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'WorkflowInstances' AND [ACTION] = 'Read';
SELECT @InstWrite = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'WorkflowInstances' AND [ACTION] = 'Write';

EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @StepRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @StepWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @InstRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @InstWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @StepRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @StepWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @InstRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @InstWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = @StepRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = @InstRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = @StepRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = @InstRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = @StepRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = @InstRead, @CreatedBy = 'seed', @PerformedBy = 1;
GO

GO

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
                 [IsStart], [IsEnd], [SLA], [DisplayOrder], [CreatedBy])
            VALUES (@WorkflowId, @StepCode, @StepTitle, @ResponsibleRoleID,
                    @IsStart, @IsEnd, @SLA, @DisplayOrder, @PerformedBy);
            SET @WorkflowStepId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE [dbo].[CMS_WorkflowSteps]
            SET [StepCode] = @StepCode, [StepTitle] = @StepTitle,
                [ResponsibleRoleID] = @ResponsibleRoleID,
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
           s.[IsStart], s.[IsEnd], s.[SLA], s.[DisplayOrder], s.[IsActive],
           s.[CreatedAt], s.[UpdatedAt],
           (SELECT COUNT(*) FROM [dbo].[CMS_WorkflowStepActions] a
             WHERE a.[WorkflowStepId] = s.[WorkflowStepId]) AS [StepActionCount],
           (SELECT COUNT(*) FROM [dbo].[CMS_WorkflowStepSections] ss
             WHERE ss.[WorkflowStepId] = s.[WorkflowStepId]) AS [StepSectionCount]
    FROM [dbo].[CMS_WorkflowSteps] s
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = s.[ResponsibleRoleID]
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
           s.[IsStart], s.[IsEnd], s.[SLA], s.[DisplayOrder], s.[IsActive],
           s.[CreatedAt], s.[UpdatedAt],
           (SELECT COUNT(*) FROM [dbo].[CMS_WorkflowStepActions] a
             WHERE a.[WorkflowStepId] = s.[WorkflowStepId]) AS [StepActionCount],
           (SELECT COUNT(*) FROM [dbo].[CMS_WorkflowStepSections] ss
             WHERE ss.[WorkflowStepId] = s.[WorkflowStepId]) AS [StepSectionCount]
    FROM [dbo].[CMS_WorkflowSteps] s
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = s.[ResponsibleRoleID]
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

    BEGIN TRY
        BEGIN TRAN;

        DELETE FROM [dbo].[CMS_WorkflowStepActions] WHERE [WorkflowStepId] = @WorkflowStepId;

        INSERT INTO [dbo].[CMS_WorkflowStepActions]
            ([WorkflowStepId], [ActionCode], [ActionTitle], [NextStepCode],
             [NextAssignmentType], [NextRoleID], [SaveOrMove], [IsSendEmail], [DisplayOrder])
        SELECT @WorkflowStepId, a.[ActionCode], a.[ActionTitle], a.[NextStepCode],
               ISNULL(a.[NextAssignmentType], 'Static'), a.[NextRoleID],
               ISNULL(a.[SaveOrMove], 1), ISNULL(a.[IsSendEmail], 0), a.[DisplayOrder]
        FROM OPENJSON(@ActionsJson)
        WITH (
            [ActionCode]         VARCHAR(100)  '$.actionCode',
            [ActionTitle]        NVARCHAR(200) '$.actionTitle',
            [NextStepCode]       VARCHAR(100)  '$.nextStepCode',
            [NextAssignmentType] VARCHAR(20)   '$.nextAssignmentType',
            [NextRoleID]         INT           '$.nextRoleId',
            [SaveOrMove]         BIT           '$.saveOrMove',
            [IsSendEmail]        BIT           '$.isSendEmail',
            [DisplayOrder]       INT           '$.displayOrder'
        ) AS a
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
           a.[SaveOrMove], a.[IsSendEmail], a.[DisplayOrder], a.[IsActive]
    FROM [dbo].[CMS_WorkflowStepActions] a
    INNER JOIN [dbo].[CMS_WorkflowSteps] s ON s.[WorkflowStepId] = a.[WorkflowStepId]
    LEFT JOIN [dbo].[CMS_WorkflowSteps] ns
        ON ns.[WorkflowId] = s.[WorkflowId] AND ns.[StepCode] = a.[NextStepCode]
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = a.[NextRoleID]
    WHERE a.[WorkflowStepId] = @WorkflowStepId AND a.[IsActive] = 1
    ORDER BY a.[DisplayOrder], a.[WorkflowStepActionId];
END
GO

/* ---- sp_CMS_WorkflowInstance_Start ----
   One instance per (workflow, submission): a form entry travels its
   route once. The instance starts on the workflow's start step
   (IsStart = 1); its role and SLA come from that step. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowInstance_Start]
    @WorkflowId    INT,
    @SubmissionId  INT,
    @Comments      NVARCHAR(MAX) = NULL,
    @PerformedBy   INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FormId INT, @StartStepCode VARCHAR(100), @StartRoleID INT, @StartSLA INT, @StartCount INT;
    SELECT @FormId = [FormId] FROM [dbo].[CMS_Workflows]
    WHERE [WorkflowId] = @WorkflowId AND [IsActive] = 1;
    IF @FormId IS NULL
        THROW 50000, 'Workflow not found or inactive.', 1;
    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_DynamicFormSubmissions]
                   WHERE [SubmissionId] = @SubmissionId AND [FormId] = @FormId)
        THROW 50000, 'Submission not found for this workflow''s form.', 1;
    IF EXISTS (SELECT 1 FROM [dbo].[CMS_WorkflowInstances]
               WHERE [WorkflowId] = @WorkflowId AND [SubmissionId] = @SubmissionId)
        THROW 50000, 'This entry already has a workflow instance.', 1;

    SELECT @StartCount = COUNT(*) FROM [dbo].[CMS_WorkflowSteps]
    WHERE [WorkflowId] = @WorkflowId AND [IsStart] = 1 AND [IsActive] = 1;
    IF @StartCount <> 1
        THROW 50000, 'The workflow must have exactly one start step.', 1;
    SELECT TOP 1 @StartStepCode = [StepCode], @StartRoleID = [ResponsibleRoleID], @StartSLA = [SLA]
    FROM [dbo].[CMS_WorkflowSteps]
    WHERE [WorkflowId] = @WorkflowId AND [IsStart] = 1 AND [IsActive] = 1;

    DECLARE @InstanceId INT;
    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO [dbo].[CMS_WorkflowInstances]
            ([WorkflowId], [SubmissionId], [CurrentStepCode], [CurrentRoleID],
             [SLA_NoOfDays], [SLA_Date], [Stage], [Comments], [CreatedBy])
        VALUES (@WorkflowId, @SubmissionId, @StartStepCode, @StartRoleID,
                @StartSLA,
                CASE WHEN @StartSLA IS NOT NULL
                     THEN DATEADD(DAY, @StartSLA, CAST(SYSUTCDATETIME() AS DATE)) ELSE NULL END,
                0, @Comments, @PerformedBy);
        SET @InstanceId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_WorkflowInstanceLogs]
            ([WorkflowInstanceId], [WorkflowId], [CurrentStepCode], [CurrentRoleID],
             [SLA_NoOfDays], [SLA_Date], [Stage], [Comments], [Status])
        VALUES (@InstanceId, @WorkflowId, @StartStepCode, @StartRoleID,
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
           i.[CurrentUserID], i.[SLA_NoOfDays], i.[SLA_Date], i.[Stage], i.[Comments],
           i.[CreatedAt], i.[UpdatedAt]
    FROM [dbo].[CMS_WorkflowInstances] i
    INNER JOIN [dbo].[CMS_Workflows] w ON w.[WorkflowId] = i.[WorkflowId]
    INNER JOIN [dbo].[CMS_DynamicForms] f ON f.[FormId] = w.[FormId]
    LEFT JOIN [dbo].[CMS_WorkflowSteps] s
        ON s.[WorkflowId] = i.[WorkflowId] AND s.[StepCode] = i.[CurrentStepCode]
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = i.[CurrentRoleID]
    WHERE i.[WorkflowInstanceId] = @WorkflowInstanceId;
END
GO

/* ---- sp_CMS_WorkflowInstance_GetMyTasks ----
   Pending work for a user: instances whose current role is one of
   the user's roles, or assigned to the user directly. Admins see
   everything pending. Finished (end-step) instances are not tasks. */
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
           i.[CurrentUserID], i.[SLA_NoOfDays], i.[SLA_Date], i.[Stage], i.[Comments],
           i.[CreatedAt], i.[UpdatedAt]
    FROM [dbo].[CMS_WorkflowInstances] i
    INNER JOIN [dbo].[CMS_Workflows] w ON w.[WorkflowId] = i.[WorkflowId]
    INNER JOIN [dbo].[CMS_DynamicForms] f ON f.[FormId] = w.[FormId]
    LEFT JOIN [dbo].[CMS_WorkflowSteps] s
        ON s.[WorkflowId] = i.[WorkflowId] AND s.[StepCode] = i.[CurrentStepCode]
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = i.[CurrentRoleID]
    WHERE ISNULL(s.[IsEnd], 0) = 0
      AND (
          @IsAdmin = 1
          OR i.[CurrentUserID] = @UserId
          OR i.[CurrentRoleID] IN (
              SELECT [ROLEID] FROM [dbo].[USER_ROLE]
              WHERE [USERID] = @UserId AND [ACTIVE] = 1)
      )
    ORDER BY CASE WHEN i.[SLA_Date] IS NULL THEN 1 ELSE 0 END, i.[SLA_Date], i.[CreatedAt] DESC;
END
GO

/* ---- sp_CMS_WorkflowInstance_GetUserAccess ----
   What the service needs for the assignment check: is the user an
   admin, and which roles do they hold. Two result sets. */
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
           a.[SaveOrMove], a.[IsSendEmail], a.[DisplayOrder], a.[IsActive]
    FROM [dbo].[CMS_WorkflowStepActions] a
    LEFT JOIN [dbo].[CMS_WorkflowSteps] ns
        ON ns.[WorkflowId] = @WorkflowId AND ns.[StepCode] = a.[NextStepCode]
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = a.[NextRoleID]
    WHERE a.[WorkflowStepId] = @StepId AND a.[IsActive] = 1
    ORDER BY a.[DisplayOrder], a.[WorkflowStepActionId];
END
GO

/* ---- sp_CMS_WorkflowInstance_ExecuteAction ----
   Press a button: the instance moves to the button's next step and
   next role, the SLA is set for the new step, and the move is logged.
   Next role: the button's role, else the next step's responsible role,
   else the role it already had. No email is sent (IsSendEmail is
   only stored). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowInstance_ExecuteAction]
    @WorkflowInstanceId INT,
    @ActionCode         VARCHAR(100),
    @Comments           NVARCHAR(MAX) = NULL,
    @PerformedBy        INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WorkflowId INT, @CurrentStepCode VARCHAR(100), @CurrentRoleID INT, @Stage INT;
    SELECT @WorkflowId = [WorkflowId], @CurrentStepCode = [CurrentStepCode],
           @CurrentRoleID = [CurrentRoleID], @Stage = [Stage]
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

    DECLARE @ActionId INT, @NextStepCode VARCHAR(100), @NextRoleID INT;
    SELECT @ActionId = [WorkflowStepActionId], @NextStepCode = [NextStepCode],
           @NextRoleID = [NextRoleID]
    FROM [dbo].[CMS_WorkflowStepActions]
    WHERE [WorkflowStepId] = @StepId AND [ActionCode] = @ActionCode AND [IsActive] = 1;
    IF @ActionId IS NULL
        THROW 50000, 'This button is not available at the current step.', 1;

    DECLARE @NextStepId INT, @NextStepSLA INT, @NextStepRoleID INT;
    SELECT @NextStepId = [WorkflowStepId], @NextStepSLA = [SLA], @NextStepRoleID = [ResponsibleRoleID]
    FROM [dbo].[CMS_WorkflowSteps]
    WHERE [WorkflowId] = @WorkflowId AND [StepCode] = @NextStepCode;
    IF @NextStepId IS NULL
        THROW 50000, 'The button''s next step no longer exists.', 1;

    DECLARE @NewRoleID INT = ISNULL(@NextRoleID, ISNULL(@NextStepRoleID, @CurrentRoleID));
    DECLARE @NewSLADate DATETIME2 = CASE WHEN @NextStepSLA IS NOT NULL
        THEN DATEADD(DAY, @NextStepSLA, CAST(SYSUTCDATETIME() AS DATE)) ELSE NULL END;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE [dbo].[CMS_WorkflowInstances]
        SET [CurrentStepCode] = @NextStepCode,
            [CurrentRoleID] = @NewRoleID,
            [SLA_NoOfDays] = @NextStepSLA,
            [SLA_Date] = @NewSLADate,
            [Comments] = ISNULL(@Comments, [Comments]),
            [UpdatedAt] = SYSUTCDATETIME()
        WHERE [WorkflowInstanceId] = @WorkflowInstanceId;

        INSERT INTO [dbo].[CMS_WorkflowInstanceLogs]
            ([WorkflowInstanceId], [WorkflowId], [CurrentStepCode], [CurrentRoleID],
             [SLA_NoOfDays], [SLA_Date], [Stage], [Comments], [Status])
        VALUES (@WorkflowInstanceId, @WorkflowId, @NextStepCode, @NewRoleID,
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
           l.[CurrentUserID], l.[SLA_NoOfDays], l.[SLA_Date], l.[Stage],
           l.[Comments], l.[LogDate], l.[Status]
    FROM [dbo].[CMS_WorkflowInstanceLogs] l
    INNER JOIN [dbo].[CMS_WorkflowInstances] i ON i.[WorkflowInstanceId] = l.[WorkflowInstanceId]
    LEFT JOIN [dbo].[CMS_WorkflowSteps] s
        ON s.[WorkflowId] = l.[WorkflowId] AND s.[StepCode] = l.[CurrentStepCode]
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = l.[CurrentRoleID]
    WHERE l.[WorkflowInstanceId] = @WorkflowInstanceId
    ORDER BY l.[LogDate] DESC, l.[WorkflowInstanceLogId] DESC;
END
GO

/* ---- sp_CMS_Workflow_Save ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Workflow_Save]
    @WorkflowId   INT,
    @WorkflowName NVARCHAR(100),
    @FormId       INT,
    @Description  NVARCHAR(500) = NULL,
    @WorkflowCode VARCHAR(50) = NULL,
    @IsActive     BIT = 1,
    @SectionsJson NVARCHAR(MAX) = NULL,
    @PerformedBy  INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @WorkflowId <> 0 AND NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Workflows] WHERE [WorkflowId] = @WorkflowId)
        THROW 50000, 'Workflow not found.', 1;
    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_DynamicForms] WHERE [FormId] = @FormId AND [IsActive] = 1)
        THROW 50000, 'Form not found or inactive.', 1;
    IF @WorkflowCode IS NOT NULL AND EXISTS (
        SELECT 1 FROM [dbo].[CMS_Workflows]
        WHERE [WorkflowCode] = @WorkflowCode AND [WorkflowId] <> @WorkflowId)
        THROW 50000, 'Another workflow already uses this code.', 1;
    IF @SectionsJson IS NOT NULL AND ISJSON(@SectionsJson) <> 1
        THROW 50000, 'Sections must be valid JSON.', 1;

    /* Section keys must be real sections of this form, and action
       types must be from the allowlist — a typo must fail here, not
       silently hide nothing on load. */
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
    IF EXISTS (
        SELECT 1 FROM OPENJSON(@SectionsJson)
        WITH ([Actions] NVARCHAR(MAX) '$.actions' AS JSON) AS s
        CROSS APPLY OPENJSON(s.[Actions])
        WITH ([ActionType] VARCHAR(50) '$.actionType') AS a
        WHERE a.[ActionType] NOT IN ('Show', 'Hide', 'Disable', 'Enable', 'Require', 'MakeOptional')
    )
        THROW 50000, 'An action type is invalid.', 1;

    DECLARE @IsNew BIT = CASE WHEN @WorkflowId = 0 THEN 1 ELSE 0 END;

    BEGIN TRY
        BEGIN TRAN;

        IF @WorkflowId = 0
        BEGIN
            INSERT INTO [dbo].[CMS_Workflows] ([WorkflowName], [FormId], [Description], [WorkflowCode], [IsActive], [CreatedBy])
            VALUES (@WorkflowName, @FormId, @Description, @WorkflowCode, @IsActive, @PerformedBy);
            SET @WorkflowId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE [dbo].[CMS_Workflows]
            SET [WorkflowName] = @WorkflowName, [FormId] = @FormId,
                [Description] = @Description, [WorkflowCode] = @WorkflowCode,
                [IsActive] = @IsActive, [UpdatedAt] = SYSUTCDATETIME()
            WHERE [WorkflowId] = @WorkflowId;
        END

        /* One active workflow per form: activating this one turns the
           others off, so GetSectionsByForm never has to guess. */
        IF @IsActive = 1
            UPDATE [dbo].[CMS_Workflows]
            SET [IsActive] = 0, [UpdatedAt] = SYSUTCDATETIME()
            WHERE [FormId] = @FormId AND [WorkflowId] <> @WorkflowId AND [IsActive] = 1;

        DELETE FROM [dbo].[CMS_WorkflowSections] WHERE [WorkflowId] = @WorkflowId;

        INSERT INTO [dbo].[CMS_WorkflowSections]
            ([WorkflowId], [SectionKey], [IsVisible], [DisplayOrder])
        SELECT @WorkflowId, s.[SectionKey], s.[IsVisible], s.[DisplayOrder]
        FROM OPENJSON(@SectionsJson)
        WITH (
            [SectionKey]   VARCHAR(100) '$.sectionKey',
            [IsVisible]    BIT          '$.isVisible',
            [DisplayOrder] INT          '$.displayOrder'
        ) AS s
        WHERE s.[SectionKey] IS NOT NULL;

        INSERT INTO [dbo].[CMS_WorkflowActions]
            ([WorkflowSectionId], [ActionType], [TargetKey], [SortOrder])
        SELECT ws.[WorkflowSectionId], a.[ActionType], a.[TargetKey], a.[SortOrder]
        FROM OPENJSON(@SectionsJson)
        WITH (
            [SectionKey] VARCHAR(100) '$.sectionKey',
            [Actions]    NVARCHAR(MAX) '$.actions' AS JSON
        ) AS s
        INNER JOIN [dbo].[CMS_WorkflowSections] ws
            ON ws.[WorkflowId] = @WorkflowId AND ws.[SectionKey] = s.[SectionKey]
        CROSS APPLY OPENJSON(s.[Actions])
        WITH (
            [ActionType] VARCHAR(50)  '$.actionType',
            [TargetKey]  VARCHAR(100) '$.targetKey',
            [SortOrder]  INT          '$.sortOrder'
        ) AS a
        WHERE a.[ActionType] IS NOT NULL;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy])
        VALUES ('CMS_Workflows', CAST(@WorkflowId AS VARCHAR(50)),
                CASE WHEN @IsNew = 1 THEN 'CREATE' ELSE 'UPDATE' END, @PerformedBy);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH

    SELECT @WorkflowId AS [WorkflowId];
END

GO

/* ---- sp_CMS_Workflow_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Workflow_GetById]
    @WorkflowId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT w.[WorkflowId], w.[WorkflowName], w.[WorkflowCode], w.[FormId], f.[FormKey], f.[Title] AS [FormTitle],
           w.[Description], w.[IsActive], w.[CreatedBy], w.[CreatedAt], w.[UpdatedAt]
    FROM [dbo].[CMS_Workflows] w
    INNER JOIN [dbo].[CMS_DynamicForms] f ON f.[FormId] = w.[FormId]
    WHERE w.[WorkflowId] = @WorkflowId;

    SELECT [WorkflowSectionId], [WorkflowId], [SectionKey], [IsVisible], [DisplayOrder], [IsActive]
    FROM [dbo].[CMS_WorkflowSections]
    WHERE [WorkflowId] = @WorkflowId
    ORDER BY [DisplayOrder], [WorkflowSectionId];

    SELECT a.[WorkflowActionId], a.[WorkflowSectionId], s.[SectionKey],
           a.[ActionType], a.[TargetKey], a.[SortOrder], a.[IsActive]
    FROM [dbo].[CMS_WorkflowActions] a
    INNER JOIN [dbo].[CMS_WorkflowSections] s ON s.[WorkflowSectionId] = a.[WorkflowSectionId]
    WHERE s.[WorkflowId] = @WorkflowId
    ORDER BY a.[SortOrder], a.[WorkflowActionId];
END

GO

/* ---- sp_CMS_Workflow_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Workflow_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT w.[WorkflowId], w.[WorkflowName], w.[WorkflowCode], w.[FormId], f.[FormKey], f.[Title] AS [FormTitle],
           w.[Description], w.[IsActive], w.[CreatedAt], w.[UpdatedAt],
           (SELECT COUNT(*) FROM [dbo].[CMS_WorkflowSections] s WHERE s.[WorkflowId] = w.[WorkflowId]) AS [SectionCount]
    FROM [dbo].[CMS_Workflows] w
    INNER JOIN [dbo].[CMS_DynamicForms] f ON f.[FormId] = w.[FormId]
    ORDER BY w.[WorkflowId];
END

GO

/* ---- sp_CMS_Workflow_GetSectionsByForm ----
   The Get Workflow Sections API's source. Returns the form's active
   workflow's sections (first result set) and their actions (second
   result set). No active workflow -> both sets are empty. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Workflow_GetSectionsByForm]
    @FormId     INT,
    @InstanceId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WorkflowId INT;
    SELECT TOP 1 @WorkflowId = [WorkflowId]
    FROM [dbo].[CMS_Workflows]
    WHERE [FormId] = @FormId AND [IsActive] = 1
    ORDER BY [UpdatedAt] DESC, [WorkflowId] DESC;

    SELECT @WorkflowId AS [WorkflowId];

    /* Step-aware: an instance at a step uses that step's section
       rows (IsVisible + IsEnable). No step rows for the step (or no
       instance) falls back to the workflow's own sections, with
       IsEnable = 1 — the form behaves exactly as before. */
    DECLARE @StepId INT = NULL;
    IF @InstanceId IS NOT NULL
    BEGIN
        SELECT @StepId = s.[WorkflowStepId]
        FROM [dbo].[CMS_WorkflowInstances] i
        INNER JOIN [dbo].[CMS_WorkflowSteps] s
            ON s.[WorkflowId] = i.[WorkflowId] AND s.[StepCode] = i.[CurrentStepCode]
        WHERE i.[WorkflowInstanceId] = @InstanceId AND i.[WorkflowId] = @WorkflowId;
    END

    IF @StepId IS NOT NULL AND EXISTS (
        SELECT 1 FROM [dbo].[CMS_WorkflowStepSections]
        WHERE [WorkflowStepId] = @StepId AND [IsActive] = 1)
    BEGIN
        SELECT ss.[SectionKey], ss.[IsVisible], ss.[IsEnable], ss.[DisplayOrder]
        FROM [dbo].[CMS_WorkflowStepSections] ss
        WHERE ss.[WorkflowStepId] = @StepId AND ss.[IsActive] = 1
        ORDER BY ss.[DisplayOrder], ss.[WorkflowStepSectionId];
    END
    ELSE
    BEGIN
        SELECT s.[SectionKey], s.[IsVisible], CAST(1 AS BIT) AS [IsEnable], s.[DisplayOrder]
        FROM [dbo].[CMS_WorkflowSections] s
        WHERE s.[WorkflowId] = @WorkflowId AND s.[IsActive] = 1
        ORDER BY s.[DisplayOrder], s.[WorkflowSectionId];
    END

    SELECT s.[SectionKey], a.[ActionType], a.[TargetKey], a.[SortOrder]
    FROM [dbo].[CMS_WorkflowActions] a
    INNER JOIN [dbo].[CMS_WorkflowSections] s ON s.[WorkflowSectionId] = a.[WorkflowSectionId]
    WHERE s.[WorkflowId] = @WorkflowId AND s.[IsActive] = 1 AND a.[IsActive] = 1
    ORDER BY a.[SortOrder], a.[WorkflowActionId];
END
GO
