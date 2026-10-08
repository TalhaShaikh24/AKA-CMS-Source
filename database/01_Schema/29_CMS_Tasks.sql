/* ============================================================
   AKA-CMS — CMS_Tasks table (Tasks & Assignments)
   Task management from the mobile design: create a task for a
   case, assign it to a role/user, track status and due dates.
   Additive and safe to re-run.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[dbo].[CMS_Tasks]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_Tasks](
        [TaskId] INT IDENTITY(1,1) NOT NULL,
        [Title] NVARCHAR(200) NOT NULL,
        [Description] NVARCHAR(MAX) NULL,
        [CaseId] INT NOT NULL,
        [TaskType] VARCHAR(50) NOT NULL CONSTRAINT [DF_CMS_Tasks_TaskType] DEFAULT ('General'),
        [Priority] VARCHAR(10) NOT NULL CONSTRAINT [DF_CMS_Tasks_Priority] DEFAULT ('Medium'),
        [DueDate] DATE NOT NULL,
        [AssignedToRoleId] INT NULL,
        [AssignedToUserId] INT NULL,
        [NotifyRecipients] NVARCHAR(500) NULL,
        [Status] VARCHAR(20) NOT NULL CONSTRAINT [DF_CMS_Tasks_Status] DEFAULT ('Pending'),
        [CompletedAt] DATETIME2 NULL,
        [CreatedBy] INT NOT NULL,
        [CreatedAt] DATETIME2 NOT NULL CONSTRAINT [DF_CMS_Tasks_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [IpAddress] VARCHAR(50) NOT NULL CONSTRAINT [DF_CMS_Tasks_IpAddress] DEFAULT ('0.0.0.0'),
        [RowVersion] ROWVERSION NOT NULL,
        CONSTRAINT [PK_CMS_Tasks] PRIMARY KEY CLUSTERED ([TaskId] ASC),
        CONSTRAINT [FK_CMS_Tasks_Cases] FOREIGN KEY ([CaseId])
            REFERENCES [dbo].[CMS_Cases] ([CaseId]),
        CONSTRAINT [FK_CMS_Tasks_AssignedUser] FOREIGN KEY ([AssignedToUserId])
            REFERENCES [dbo].[USERS] ([USERID]),
        CONSTRAINT [FK_CMS_Tasks_AssignedRole] FOREIGN KEY ([AssignedToRoleId])
            REFERENCES [dbo].[ROLES] ([ROLEID]),
        CONSTRAINT [CK_CMS_Tasks_Priority] CHECK ([Priority] IN ('High', 'Medium', 'Low')),
        CONSTRAINT [CK_CMS_Tasks_Status] CHECK ([Status] IN ('Pending', 'InProgress', 'Completed', 'Cancelled'))
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_Tasks_Case] ON [dbo].[CMS_Tasks] ([CaseId] ASC);
    CREATE NONCLUSTERED INDEX [IX_CMS_Tasks_Assignee] ON [dbo].[CMS_Tasks] ([AssignedToUserId] ASC);
    CREATE NONCLUSTERED INDEX [IX_CMS_Tasks_DueDate] ON [dbo].[CMS_Tasks] ([DueDate] ASC);
END
GO

/* ---- Permission catalog entries ----
   IDs are allocated dynamically (MAX+1), like the Sprint9 seed —
   never hardcode an ID in the >= 90000 range. */
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
        ('Tasks', 'Read'),
        ('Tasks', 'Write')
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

/* ---- Grants: admin full, supervisor write, frontline roles read ----
   Resolved by (CONTROLLERNAME, ACTION) so re-runs stay idempotent. */
DECLARE @TaskRead INT, @TaskWrite INT;
SELECT @TaskRead = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'Tasks' AND [ACTION] = 'Read';
SELECT @TaskWrite = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'Tasks' AND [ACTION] = 'Write';

EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @TaskRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @TaskWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @TaskRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @TaskWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = @TaskRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = @TaskRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = @TaskRead, @CreatedBy = 'seed', @PerformedBy = 1;
GO
