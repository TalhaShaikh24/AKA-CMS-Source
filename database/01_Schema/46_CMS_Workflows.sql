/* ============================================================================
   46_CMS_Workflows.sql
   Form-section Workflow (boss request 2026-11-05): on a Dynamic Form,
   some sections show and some hide on load, driven by the Workflow
   project's Get Workflow Sections API.

   This is NOT the case workflow engine (13 states / 22 transitions
   for cases). This workflow controls form sections only.

   Tables:
     CMS_Workflows         one workflow per form (only one active at a
                           time per form — the one that runs on load)
     CMS_WorkflowSections  which sections belong to the workflow, and
                           whether each one shows on load
     CMS_WorkflowActions   what the workflow does to a section/field
                           when the form loads (Show / Hide / Disable /
                           Enable / Require / MakeOptional)

   A section is a CMS_DynamicFormFields row with FieldType = 'section',
   identified by its FieldKey (SectionKey). Its child fields hide and
   show with it. The Workflow project is separate and talks in keys,
   not in our internal FieldIds, so the link is by key.
   ============================================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('dbo.CMS_Workflows', 'WorkflowId') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_Workflows] (
        [WorkflowId]   INT IDENTITY(1,1) NOT NULL CONSTRAINT [PK_CMS_Workflows] PRIMARY KEY,
        [WorkflowName] NVARCHAR(100) NOT NULL,
        [FormId]       INT NOT NULL CONSTRAINT [FK_CMS_Workflows_Form] FOREIGN KEY
                           REFERENCES [dbo].[CMS_DynamicForms] ([FormId]),
        [Description]  NVARCHAR(500) NULL,
        [IsActive]     BIT NOT NULL CONSTRAINT [DF_CMS_Workflows_IsActive] DEFAULT (1),
        [CreatedBy]    INT NULL,
        [CreatedAt]    DATETIME2 NOT NULL CONSTRAINT [DF_CMS_Workflows_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [UpdatedAt]    DATETIME2 NULL
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_Workflows_Form] ON [dbo].[CMS_Workflows] ([FormId], [IsActive]);
END
GO

IF COL_LENGTH('dbo.CMS_WorkflowSections', 'WorkflowSectionId') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_WorkflowSections] (
        [WorkflowSectionId] INT IDENTITY(1,1) NOT NULL CONSTRAINT [PK_CMS_WorkflowSections] PRIMARY KEY,
        [WorkflowId]        INT NOT NULL CONSTRAINT [FK_CMS_WorkflowSections_Workflow] FOREIGN KEY
                                REFERENCES [dbo].[CMS_Workflows] ([WorkflowId]) ON DELETE CASCADE,
        [SectionKey]        VARCHAR(100) NOT NULL,
        [IsVisible]         BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowSections_IsVisible] DEFAULT (1),
        [DisplayOrder]      INT NOT NULL CONSTRAINT [DF_CMS_WorkflowSections_DisplayOrder] DEFAULT (0),
        [IsActive]          BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowSections_IsActive] DEFAULT (1),
        [CreatedAt]         DATETIME2 NOT NULL CONSTRAINT [DF_CMS_WorkflowSections_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [UQ_CMS_WorkflowSections_Workflow_Section] UNIQUE ([WorkflowId], [SectionKey])
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_WorkflowSections_Workflow] ON [dbo].[CMS_WorkflowSections] ([WorkflowId], [DisplayOrder]);
END
GO

IF COL_LENGTH('dbo.CMS_WorkflowActions', 'WorkflowActionId') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_WorkflowActions] (
        [WorkflowActionId]  INT IDENTITY(1,1) NOT NULL CONSTRAINT [PK_CMS_WorkflowActions] PRIMARY KEY,
        [WorkflowSectionId] INT NOT NULL CONSTRAINT [FK_CMS_WorkflowActions_Section] FOREIGN KEY
                                REFERENCES [dbo].[CMS_WorkflowSections] ([WorkflowSectionId]) ON DELETE CASCADE,
        [ActionType]        VARCHAR(50) NOT NULL,
        [TargetKey]         VARCHAR(100) NULL,
        [SortOrder]         INT NOT NULL CONSTRAINT [DF_CMS_WorkflowActions_SortOrder] DEFAULT (0),
        [IsActive]          BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowActions_IsActive] DEFAULT (1),
        [CreatedAt]         DATETIME2 NOT NULL CONSTRAINT [DF_CMS_WorkflowActions_CreatedAt] DEFAULT (SYSUTCDATETIME())
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_WorkflowActions_Section] ON [dbo].[CMS_WorkflowActions] ([WorkflowSectionId], [SortOrder]);
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
        ('Workflows', 'Read'),
        ('Workflows', 'Write')
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

/* ---- Grants: admin + supervisor full, frontline roles read ---- */
DECLARE @WfRead INT, @WfWrite INT;
SELECT @WfRead = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'Workflows' AND [ACTION] = 'Read';
SELECT @WfWrite = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'Workflows' AND [ACTION] = 'Write';

EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @WfRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @WfWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @WfRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @WfWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = @WfRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = @WfRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = @WfRead, @CreatedBy = 'seed', @PerformedBy = 1;
GO
