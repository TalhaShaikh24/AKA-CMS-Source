/* ============================================================
   AKA-CMS — Task management stored procedures
   (Tasks & Assignments from the mobile design)
   Write procs run in a transaction and write CMS_AuditLogs.

   Custom THROW numbers (project-wide):
     50005 - row-version mismatch (optimistic concurrency)
     50008 - entity not found
     50011 - duplicate/conflict
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_Task_GetAll ----
   @Tab: 'All' | 'DueToday' | 'Overdue' (mirrors the mobile tabs).
   Overdue = past due date and not Completed/Cancelled. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Task_GetAll]
    @Tab VARCHAR(20) = 'All',
    @CaseId INT = NULL,
    @AssignedToUserId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Today DATE = CAST(SYSUTCDATETIME() AS DATE);

    SELECT  t.[TaskId],
            t.[Title],
            t.[Description],
            t.[CaseId],
            c.[CaseNumber],
            m.[FullName] AS [PatientName],
            t.[TaskType],
            t.[Priority],
            t.[DueDate],
            t.[AssignedToRoleId],
            r.[DESCRIPTION] AS [AssignedRoleName],
            t.[AssignedToUserId],
            u.[USERNAME] AS [AssignedUserName],
            t.[NotifyRecipients],
            t.[Status],
            t.[CompletedAt],
            t.[RowVersion]
    FROM [dbo].[CMS_Tasks] t
    INNER JOIN [dbo].[CMS_Cases] c ON c.[CaseId] = t.[CaseId]
    INNER JOIN [dbo].[CMS_CommunityMembers] m ON m.[MemberId] = c.[CommunityMemberId]
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = t.[AssignedToUserId]
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = t.[AssignedToRoleId]
    WHERE (@CaseId IS NULL OR t.[CaseId] = @CaseId)
      AND (@AssignedToUserId IS NULL OR t.[AssignedToUserId] = @AssignedToUserId)
      AND (
            @Tab = 'All'
            OR (@Tab = 'DueToday' AND t.[DueDate] = @Today AND t.[Status] NOT IN ('Completed', 'Cancelled'))
            OR (@Tab = 'Overdue' AND t.[DueDate] < @Today AND t.[Status] NOT IN ('Completed', 'Cancelled'))
          )
    ORDER BY t.[DueDate], t.[TaskId];
END
GO

/* ---- sp_CMS_Task_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Task_GetById]
    @TaskId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  t.[TaskId],
            t.[Title],
            t.[Description],
            t.[CaseId],
            c.[CaseNumber],
            m.[FullName] AS [PatientName],
            t.[TaskType],
            t.[Priority],
            t.[DueDate],
            t.[AssignedToRoleId],
            r.[DESCRIPTION] AS [AssignedRoleName],
            t.[AssignedToUserId],
            u.[USERNAME] AS [AssignedUserName],
            t.[NotifyRecipients],
            t.[Status],
            t.[CompletedAt],
            t.[RowVersion]
    FROM [dbo].[CMS_Tasks] t
    INNER JOIN [dbo].[CMS_Cases] c ON c.[CaseId] = t.[CaseId]
    INNER JOIN [dbo].[CMS_CommunityMembers] m ON m.[MemberId] = c.[CommunityMemberId]
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = t.[AssignedToUserId]
    LEFT JOIN [dbo].[ROLES] r ON r.[ROLEID] = t.[AssignedToRoleId]
    WHERE t.[TaskId] = @TaskId;
END
GO

/* ---- sp_CMS_Task_Create ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Task_Create]
    @Title NVARCHAR(200),
    @Description NVARCHAR(MAX) = NULL,
    @CaseId INT,
    @TaskType VARCHAR(50) = 'General',
    @Priority VARCHAR(10) = 'Medium',
    @DueDate DATE,
    @AssignedToRoleId INT = NULL,
    @AssignedToUserId INT = NULL,
    @NotifyRecipients NVARCHAR(500) = NULL,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewTaskId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId)
            THROW 50008, 'Case not found.', 1;

        IF @AssignedToUserId IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERID] = @AssignedToUserId)
            THROW 50008, 'Assigned user not found.', 1;

        IF @AssignedToRoleId IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM [dbo].[ROLES] WHERE [ROLEID] = @AssignedToRoleId)
            THROW 50008, 'Assigned role not found.', 1;

        INSERT INTO [dbo].[CMS_Tasks]
            ([Title], [Description], [CaseId], [TaskType], [Priority], [DueDate],
             [AssignedToRoleId], [AssignedToUserId], [NotifyRecipients],
             [Status], [CreatedBy], [IpAddress])
        VALUES
            (@Title, @Description, @CaseId, @TaskType, @Priority, @DueDate,
             @AssignedToRoleId, @AssignedToUserId, @NotifyRecipients,
             'Pending', @CreatedBy, @IpAddress);

        SET @NewTaskId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Tasks', CAST(@NewTaskId AS VARCHAR(50)), 'INSERT', @CreatedBy, @Title);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Task_UpdateStatus ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Task_UpdateStatus]
    @TaskId INT,
    @Status VARCHAR(20),
    @RowVersion ROWVERSION,
    @PerformedBy INT,
    @IpAddress VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Tasks]
                       WHERE [TaskId] = @TaskId AND [RowVersion] = @RowVersion)
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Tasks] WHERE [TaskId] = @TaskId)
                THROW 50008, 'Task not found.', 1;
            THROW 50005, 'The task was modified by another user.', 1;
        END

        UPDATE [dbo].[CMS_Tasks]
        SET [Status] = @Status,
            [CompletedAt] = CASE WHEN @Status = 'Completed' THEN SYSUTCDATETIME() ELSE [CompletedAt] END
        WHERE [TaskId] = @TaskId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Tasks', CAST(@TaskId AS VARCHAR(50)), 'STATUS', @PerformedBy, @Status);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Task_Assign ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Task_Assign]
    @TaskId INT,
    @AssignedToRoleId INT = NULL,
    @AssignedToUserId INT = NULL,
    @RowVersion ROWVERSION,
    @PerformedBy INT,
    @IpAddress VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Tasks]
                       WHERE [TaskId] = @TaskId AND [RowVersion] = @RowVersion)
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Tasks] WHERE [TaskId] = @TaskId)
                THROW 50008, 'Task not found.', 1;
            THROW 50005, 'The task was modified by another user.', 1;
        END

        IF @AssignedToUserId IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERID] = @AssignedToUserId)
            THROW 50008, 'Assigned user not found.', 1;

        IF @AssignedToRoleId IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM [dbo].[ROLES] WHERE [ROLEID] = @AssignedToRoleId)
            THROW 50008, 'Assigned role not found.', 1;

        UPDATE [dbo].[CMS_Tasks]
        SET [AssignedToRoleId] = @AssignedToRoleId,
            [AssignedToUserId] = @AssignedToUserId
        WHERE [TaskId] = @TaskId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Tasks', CAST(@TaskId AS VARCHAR(50)), 'ASSIGN', @PerformedBy,
                'RoleId=' + ISNULL(CAST(@AssignedToRoleId AS VARCHAR(10)), '-') +
                ';UserId=' + ISNULL(CAST(@AssignedToUserId AS VARCHAR(10)), '-'));

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
