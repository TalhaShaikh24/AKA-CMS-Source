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
