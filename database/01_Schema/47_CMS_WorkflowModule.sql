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
        [UpdatedAt]          DATETIME2 NULL
    );
    -- One instance per (workflow, entry) — but only when an entry
    -- exists. Instance-first start (2026-11-10) creates requests with
    -- SubmissionId NULL, and a plain UNIQUE constraint treats NULL as
    -- a value, so it would allow only ONE unfilled request per
    -- workflow. A filtered index enforces uniqueness only for linked
    -- entries and lets unfilled requests repeat. Filtered indexes
    -- need QUOTED_IDENTIFIER ON (Msg 1934 otherwise).
    SET QUOTED_IDENTIFIER ON;
    CREATE UNIQUE NONCLUSTERED INDEX [UQ_CMS_WorkflowInstances_Workflow_Submission]
        ON [dbo].[CMS_WorkflowInstances] ([WorkflowId], [SubmissionId])
        WHERE [SubmissionId] IS NOT NULL;
    CREATE NONCLUSTERED INDEX [IX_CMS_WorkflowInstances_CurrentRole] ON [dbo].[CMS_WorkflowInstances] ([CurrentRoleID], [CurrentStepCode]);
    CREATE NONCLUSTERED INDEX [IX_CMS_WorkflowInstances_Submission] ON [dbo].[CMS_WorkflowInstances] ([SubmissionId]);
END
GO

-- Existing databases (2026-11-10): replace the plain UNIQUE constraint
-- with the filtered index above, so several unfilled requests per
-- workflow are allowed. Safe: the old constraint already enforced the
-- same rule for linked entries. Filtered indexes need
-- QUOTED_IDENTIFIER ON (Msg 1934 otherwise).
SET QUOTED_IDENTIFIER ON;
GO
IF EXISTS (SELECT 1 FROM sys.key_constraints
           WHERE [name] = 'UQ_CMS_WorkflowInstances_Workflow_Submission'
             AND [parent_object_id] = OBJECT_ID('dbo.CMS_WorkflowInstances'))
    ALTER TABLE [dbo].[CMS_WorkflowInstances]
        DROP CONSTRAINT [UQ_CMS_WorkflowInstances_Workflow_Submission];
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE [name] = 'UQ_CMS_WorkflowInstances_Workflow_Submission'
                 AND [object_id] = OBJECT_ID('dbo.CMS_WorkflowInstances'))
    CREATE UNIQUE NONCLUSTERED INDEX [UQ_CMS_WorkflowInstances_Workflow_Submission]
        ON [dbo].[CMS_WorkflowInstances] ([WorkflowId], [SubmissionId])
        WHERE [SubmissionId] IS NOT NULL;
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
