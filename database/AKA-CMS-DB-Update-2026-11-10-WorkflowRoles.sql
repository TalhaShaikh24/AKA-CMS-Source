/* ============================================================================
   AKA-CMS-DB-Update-2026-11-10-WorkflowRoles.sql
   Workflow roles + My Requests (2026-11-10) — ONE file, run in order:
     1. 48_CMS_WorkflowRoles.sql   (2 new tables + 4 new columns +
                                    WorkflowRoles Read/Write permissions)
     2. 36_WorkflowRoles.sql      (8 new stored procedures)
     3. 35_WorkflowModule.sql     (FULL file, all 15 procedures —
                                    12 updated for workflow roles)
   Idempotent: safe to re-run. After running: restart the API, then
   log out and back in (new permissions load at startup, JWT claims
   at login).
   Prerequisite: the 2026-11-07 WorkflowModule file (47 + 35 + 34)
   must already have run — this file builds on those tables/SPs.
   ============================================================================ */

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

/* ============================================================================
   36_WorkflowRoles.sql
   Workflow roles stored procedures (2026-11-10): the workflow-role
   list, which users hold which workflow roles, and My Requests
   (instances the user started themselves).

   Assignment is a union: a step (or button) may name a user role, a
   workflow role, or both. My Tasks and the execute check match
   EITHER one — a user with no workflow roles is unaffected, and a
   step with no workflow role keeps working on its user role.
   ============================================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_WorkflowRole_Save (one workflow role, upsert) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowRole_Save]
    @WorkflowRoleId   INT,
    @WorkflowRoleCode VARCHAR(50),
    @Title            NVARCHAR(200),
    @Description      NVARCHAR(500) = NULL,
    @PerformedBy      INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @WorkflowRoleCode IS NULL OR LTRIM(RTRIM(@WorkflowRoleCode)) = ''
        THROW 50000, 'Workflow role code is required.', 1;
    IF @Title IS NULL OR LTRIM(RTRIM(@Title)) = ''
        THROW 50000, 'Workflow role title is required.', 1;
    IF EXISTS (SELECT 1 FROM [dbo].[CMS_WorkflowRoles]
               WHERE [WorkflowRoleCode] = @WorkflowRoleCode
                 AND [WorkflowRoleId] <> @WorkflowRoleId)
        THROW 50000, 'A workflow role with this code already exists.', 1;

    DECLARE @IsNew BIT = CASE WHEN @WorkflowRoleId = 0 THEN 1 ELSE 0 END;

    BEGIN TRY
        BEGIN TRAN;

        IF @WorkflowRoleId = 0
        BEGIN
            INSERT INTO [dbo].[CMS_WorkflowRoles]
                ([WorkflowRoleCode], [Title], [Description], [CreatedBy])
            VALUES (@WorkflowRoleCode, @Title, @Description, @PerformedBy);
            SET @WorkflowRoleId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_WorkflowRoles] WHERE [WorkflowRoleId] = @WorkflowRoleId)
                THROW 50000, 'Workflow role not found.', 1;
            UPDATE [dbo].[CMS_WorkflowRoles]
            SET [WorkflowRoleCode] = @WorkflowRoleCode, [Title] = @Title,
                [Description] = @Description, [UpdatedAt] = SYSUTCDATETIME()
            WHERE [WorkflowRoleId] = @WorkflowRoleId;
        END

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy])
        VALUES ('CMS_WorkflowRoles', CAST(@WorkflowRoleId AS VARCHAR(50)),
                CASE WHEN @IsNew = 1 THEN 'CREATE' ELSE 'UPDATE' END, @PerformedBy);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH

    SELECT @WorkflowRoleId AS [WorkflowRoleId];
END
GO

/* ---- sp_CMS_WorkflowRole_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowRole_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT r.[WorkflowRoleId], r.[WorkflowRoleCode], r.[Title], r.[Description],
           r.[IsActive], r.[CreatedAt], r.[UpdatedAt],
           (SELECT COUNT(*) FROM [dbo].[CMS_UserWorkflowRoles] m
             WHERE m.[WorkflowRoleId] = r.[WorkflowRoleId] AND m.[IsActive] = 1) AS [UserCount]
    FROM [dbo].[CMS_WorkflowRoles] r
    ORDER BY r.[Title], r.[WorkflowRoleId];
END
GO

/* ---- sp_CMS_WorkflowRole_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowRole_GetById]
    @WorkflowRoleId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT r.[WorkflowRoleId], r.[WorkflowRoleCode], r.[Title], r.[Description],
           r.[IsActive], r.[CreatedAt], r.[UpdatedAt],
           (SELECT COUNT(*) FROM [dbo].[CMS_UserWorkflowRoles] m
             WHERE m.[WorkflowRoleId] = r.[WorkflowRoleId] AND m.[IsActive] = 1) AS [UserCount]
    FROM [dbo].[CMS_WorkflowRoles] r
    WHERE r.[WorkflowRoleId] = @WorkflowRoleId;
END
GO

/* ---- sp_CMS_WorkflowRole_Delete (soft: deactivate) ----
   Steps and buttons keep pointing at the role; they just cannot
   pick it again (dropdowns list active roles only), and My Tasks
   stops matching it. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowRole_Delete]
    @WorkflowRoleId INT,
    @PerformedBy    INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_WorkflowRoles] WHERE [WorkflowRoleId] = @WorkflowRoleId)
        THROW 50000, 'Workflow role not found.', 1;

    UPDATE [dbo].[CMS_WorkflowRoles]
    SET [IsActive] = 0, [UpdatedAt] = SYSUTCDATETIME()
    WHERE [WorkflowRoleId] = @WorkflowRoleId;

    INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy])
    VALUES ('CMS_WorkflowRoles', CAST(@WorkflowRoleId AS VARCHAR(50)), 'DELETE', @PerformedBy);
END
GO

/* ---- sp_CMS_UserWorkflowRole_SaveByRole (wholesale replace per role) ----
   @UserIdsJson is a JSON array of user ids, e.g. [1, 2, 3]. NULL or
   [] unassigns everyone. A user id that is not a real user fails
   the whole save (400, nothing changes). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_UserWorkflowRole_SaveByRole]
    @WorkflowRoleId INT,
    @UserIdsJson    NVARCHAR(MAX) = NULL,
    @PerformedBy    INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_WorkflowRoles]
                   WHERE [WorkflowRoleId] = @WorkflowRoleId AND [IsActive] = 1)
        THROW 50000, 'Workflow role not found or inactive.', 1;
    IF @UserIdsJson IS NOT NULL AND ISJSON(@UserIdsJson) <> 1
        THROW 50000, 'Users must be valid JSON.', 1;
    IF EXISTS (
        SELECT 1 FROM OPENJSON(@UserIdsJson)
        WHERE ISNULL(TRY_CAST([value] AS INT), -1) NOT IN (SELECT [USERID] FROM [dbo].[USERS])
    )
        THROW 50000, 'A user id is not a real user.', 1;

    BEGIN TRY
        BEGIN TRAN;

        DELETE FROM [dbo].[CMS_UserWorkflowRoles] WHERE [WorkflowRoleId] = @WorkflowRoleId;

        INSERT INTO [dbo].[CMS_UserWorkflowRoles]
            ([UserId], [WorkflowRoleId], [CreatedBy])
        SELECT DISTINCT CAST([value] AS INT), @WorkflowRoleId, @PerformedBy
        FROM OPENJSON(@UserIdsJson)
        WHERE TRY_CAST([value] AS INT) IS NOT NULL;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy])
        VALUES ('CMS_UserWorkflowRoles', CAST(@WorkflowRoleId AS VARCHAR(50)), 'UPDATE', @PerformedBy);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_UserWorkflowRole_GetUsersByRole ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_UserWorkflowRole_GetUsersByRole]
    @WorkflowRoleId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.[UserWorkflowRoleId], m.[UserId], u.[USERNAME] AS [Username],
           u.[EMAIL] AS [Email], m.[CreatedAt]
    FROM [dbo].[CMS_UserWorkflowRoles] m
    INNER JOIN [dbo].[USERS] u ON u.[USERID] = m.[UserId]
    WHERE m.[WorkflowRoleId] = @WorkflowRoleId AND m.[IsActive] = 1
    ORDER BY u.[USERNAME];
END
GO

/* ---- sp_CMS_UserWorkflowRole_GetByUser ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_UserWorkflowRole_GetByUser]
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT r.[WorkflowRoleId], r.[WorkflowRoleCode], r.[Title], r.[Description],
           r.[IsActive], m.[CreatedAt]
    FROM [dbo].[CMS_UserWorkflowRoles] m
    INNER JOIN [dbo].[CMS_WorkflowRoles] r ON r.[WorkflowRoleId] = m.[WorkflowRoleId]
    WHERE m.[UserId] = @UserId AND m.[IsActive] = 1 AND r.[IsActive] = 1
    ORDER BY r.[Title];
END
GO

/* ---- sp_CMS_WorkflowInstance_GetMyRequests ----
   Requests the user started themselves (CreatedBy = the user who
   pressed the first step button). Finished (end-step) instances
   are included — a request stays visible after it completes. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowInstance_GetMyRequests]
    @UserId INT
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
    WHERE i.[CreatedBy] = @UserId
    ORDER BY i.[CreatedAt] DESC;
END
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
            UPDATE [dbo].[CMS_WorkflowSteps]
            SET [StepCode] = @StepCode, [StepTitle] = @StepTitle,
                [ResponsibleRoleID] = @ResponsibleRoleID,
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

        DELETE FROM [dbo].[CMS_WorkflowStepActions] WHERE [WorkflowStepId] = @WorkflowStepId;

        INSERT INTO [dbo].[CMS_WorkflowStepActions]
            ([WorkflowStepId], [ActionCode], [ActionTitle], [NextStepCode],
             [NextAssignmentType], [NextRoleID], [NextWorkflowRoleID], [SaveOrMove], [IsSendEmail], [DisplayOrder])
        SELECT @WorkflowStepId, a.[ActionCode], a.[ActionTitle], a.[NextStepCode],
               ISNULL(a.[NextAssignmentType], 'Static'), a.[NextRoleID], a.[NextWorkflowRoleID],
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
   (IsStart = 1); its role and SLA come from that step. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowInstance_Start]
    @WorkflowId    INT,
    @SubmissionId  INT,
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
    SELECT TOP 1 @StartStepCode = [StepCode], @StartRoleID = [ResponsibleRoleID], @StartWorkflowRoleID = [ResponsibleWorkflowRoleID], @StartSLA = [SLA]
    FROM [dbo].[CMS_WorkflowSteps]
    WHERE [WorkflowId] = @WorkflowId AND [IsStart] = 1 AND [IsActive] = 1;

    DECLARE @InstanceId INT;
    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO [dbo].[CMS_WorkflowInstances]
            ([WorkflowId], [SubmissionId], [CurrentStepCode], [CurrentRoleID],
             [CurrentWorkflowRoleID],
             [SLA_NoOfDays], [SLA_Date], [Stage], [Comments], [CreatedBy])
        VALUES (@WorkflowId, @SubmissionId, @StartStepCode, @StartRoleID,
                @StartWorkflowRoleID,
                @StartSLA,
                CASE WHEN @StartSLA IS NOT NULL
                     THEN DATEADD(DAY, @StartSLA, CAST(SYSUTCDATETIME() AS DATE)) ELSE NULL END,
                0, @Comments, @PerformedBy);
        SET @InstanceId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_WorkflowInstanceLogs]
            ([WorkflowInstanceId], [WorkflowId], [CurrentStepCode], [CurrentRoleID],
             [CurrentWorkflowRoleID],
             [SLA_NoOfDays], [SLA_Date], [Stage], [Comments], [Status])
        VALUES (@InstanceId, @WorkflowId, @StartStepCode, @StartRoleID,
                @StartWorkflowRoleID,
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
   only stored). */
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
            [SLA_NoOfDays] = @NextStepSLA,
            [SLA_Date] = @NewSLADate,
            [Comments] = ISNULL(@Comments, [Comments]),
            [UpdatedAt] = SYSUTCDATETIME()
        WHERE [WorkflowInstanceId] = @WorkflowInstanceId;

        INSERT INTO [dbo].[CMS_WorkflowInstanceLogs]
            ([WorkflowInstanceId], [WorkflowId], [CurrentStepCode], [CurrentRoleID],
             [CurrentWorkflowRoleID],
             [SLA_NoOfDays], [SLA_Date], [Stage], [Comments], [Status])
        VALUES (@WorkflowInstanceId, @WorkflowId, @NextStepCode, @NewRoleID,
                @NewWorkflowRoleID,
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
