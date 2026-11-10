/* ============================================================================
   48_CMS_WorkflowRoles.sql
   Workflow roles (2026-11-10): a role list that belongs to workflows,
   NOT to users. A user role (ROLES) says what a user may do in the
   app; a workflow role says who a workflow step is waiting on.
   Assigning a workflow role to a user is OPTIONAL — a user with no
   workflow roles simply never matches a workflow-role assignment,
   and steps keep working on their user role (union matching).

   New tables:
     CMS_WorkflowRoles      the workflow-role list (code + title)
     CMS_UserWorkflowRoles  which users hold which workflow roles
   New columns (all NULLable, so old rows keep working):
     CMS_WorkflowSteps.ResponsibleWorkflowRoleID
     CMS_WorkflowStepActions.NextWorkflowRoleID
     CMS_WorkflowInstances.CurrentWorkflowRoleID
     CMS_WorkflowInstanceLogs.CurrentWorkflowRoleID
   Permissions are dynamic like every other module: the
   WorkflowRoles Read/Write rows go into AllCONTROLLERS here, the
   policy catalog picks them up at API startup, no code lists them.
   ============================================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- CMS_WorkflowRoles ---- */
IF COL_LENGTH('dbo.CMS_WorkflowRoles', 'WorkflowRoleId') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_WorkflowRoles] (
        [WorkflowRoleId]   INT IDENTITY(1,1) NOT NULL CONSTRAINT [PK_CMS_WorkflowRoles] PRIMARY KEY,
        [WorkflowRoleCode] VARCHAR(50) NOT NULL,
        [Title]            NVARCHAR(200) NOT NULL,
        [Description]      NVARCHAR(500) NULL,
        [IsActive]         BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowRoles_IsActive] DEFAULT (1),
        [CreatedBy]        INT NULL,
        [CreatedAt]        DATETIME2 NOT NULL CONSTRAINT [DF_CMS_WorkflowRoles_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [UpdatedAt]        DATETIME2 NULL,
        CONSTRAINT [UQ_CMS_WorkflowRoles_Code] UNIQUE ([WorkflowRoleCode])
    );
END
GO

/* ---- CMS_UserWorkflowRoles ---- */
IF COL_LENGTH('dbo.CMS_UserWorkflowRoles', 'UserWorkflowRoleId') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_UserWorkflowRoles] (
        [UserWorkflowRoleId] INT IDENTITY(1,1) NOT NULL CONSTRAINT [PK_CMS_UserWorkflowRoles] PRIMARY KEY,
        [UserId]             INT NOT NULL CONSTRAINT [FK_CMS_UserWorkflowRoles_User] FOREIGN KEY
                                 REFERENCES [dbo].[USERS] ([USERID]),
        [WorkflowRoleId]     INT NOT NULL CONSTRAINT [FK_CMS_UserWorkflowRoles_Role] FOREIGN KEY
                                 REFERENCES [dbo].[CMS_WorkflowRoles] ([WorkflowRoleId]),
        [IsActive]           BIT NOT NULL CONSTRAINT [DF_CMS_UserWorkflowRoles_IsActive] DEFAULT (1),
        [CreatedBy]          INT NULL,
        [CreatedAt]          DATETIME2 NOT NULL CONSTRAINT [DF_CMS_UserWorkflowRoles_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [UQ_CMS_UserWorkflowRoles_User_Role] UNIQUE ([UserId], [WorkflowRoleId])
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_UserWorkflowRoles_Role] ON [dbo].[CMS_UserWorkflowRoles] ([WorkflowRoleId], [IsActive]);
    CREATE NONCLUSTERED INDEX [IX_CMS_UserWorkflowRoles_User] ON [dbo].[CMS_UserWorkflowRoles] ([UserId], [IsActive]);
END
GO

/* ---- CMS_WorkflowSteps.ResponsibleWorkflowRoleID ---- */
IF COL_LENGTH('dbo.CMS_WorkflowSteps', 'ResponsibleWorkflowRoleID') IS NULL
BEGIN
    ALTER TABLE [dbo].[CMS_WorkflowSteps]
        ADD [ResponsibleWorkflowRoleID] INT NULL
            CONSTRAINT [FK_CMS_WorkflowSteps_WorkflowRole] FOREIGN KEY
            REFERENCES [dbo].[CMS_WorkflowRoles] ([WorkflowRoleId]);
END
GO

/* ---- CMS_WorkflowStepActions.NextWorkflowRoleID ---- */
IF COL_LENGTH('dbo.CMS_WorkflowStepActions', 'NextWorkflowRoleID') IS NULL
BEGIN
    ALTER TABLE [dbo].[CMS_WorkflowStepActions]
        ADD [NextWorkflowRoleID] INT NULL
            CONSTRAINT [FK_CMS_WorkflowStepActions_WorkflowRole] FOREIGN KEY
            REFERENCES [dbo].[CMS_WorkflowRoles] ([WorkflowRoleId]);
END
GO

/* ---- CMS_WorkflowInstances.CurrentWorkflowRoleID ---- */
IF COL_LENGTH('dbo.CMS_WorkflowInstances', 'CurrentWorkflowRoleID') IS NULL
BEGIN
    ALTER TABLE [dbo].[CMS_WorkflowInstances]
        ADD [CurrentWorkflowRoleID] INT NULL
            CONSTRAINT [FK_CMS_WorkflowInstances_WorkflowRole] FOREIGN KEY
            REFERENCES [dbo].[CMS_WorkflowRoles] ([WorkflowRoleId]);
    CREATE NONCLUSTERED INDEX [IX_CMS_WorkflowInstances_CurrentWorkflowRole]
        ON [dbo].[CMS_WorkflowInstances] ([CurrentWorkflowRoleID], [CurrentStepCode]);
END
GO

/* ---- CMS_WorkflowInstanceLogs.CurrentWorkflowRoleID ---- */
IF COL_LENGTH('dbo.CMS_WorkflowInstanceLogs', 'CurrentWorkflowRoleID') IS NULL
BEGIN
    ALTER TABLE [dbo].[CMS_WorkflowInstanceLogs]
        ADD [CurrentWorkflowRoleID] INT NULL
            CONSTRAINT [FK_CMS_WorkflowInstanceLogs_WorkflowRole] FOREIGN KEY
            REFERENCES [dbo].[CMS_WorkflowRoles] ([WorkflowRoleId]);
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
        ('WorkflowRoles', 'Read'),
        ('WorkflowRoles', 'Write')
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

/* ---- Grants: roles 1-2 read + write, roles 3-5 read ---- */
DECLARE @RolesRead INT, @RolesWrite INT;
SELECT @RolesRead = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'WorkflowRoles' AND [ACTION] = 'Read';
SELECT @RolesWrite = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'WorkflowRoles' AND [ACTION] = 'Write';

EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @RolesRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @RolesWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @RolesRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @RolesWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = @RolesRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = @RolesRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = @RolesRead, @CreatedBy = 'seed', @PerformedBy = 1;
GO
