/* ============================================================================
   34_Workflows.sql
   Form-section Workflow stored procedures (boss request 2026-11-05).

   Save replaces a workflow's sections and actions wholesale (the same
   pattern as DynamicForm Save): the caller sends the full section
   list every time, so there is no drift between the workflow the user
   sees and the one stored. Activating a workflow deactivates the
   other active workflows for the same form, so exactly one workflow
   runs on load.

   GetSectionsByForm is the Get Workflow Sections API's source: the
   form's active workflow, its sections in display order, and each
   section's actions in sort order. No active workflow -> empty sets,
   and the form shows everything (the safe default).
   ============================================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
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

/* ---- sp_CMS_Workflow_Delete (soft: deactivate) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Workflow_Delete]
    @WorkflowId  INT,
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [dbo].[CMS_Workflows]
    SET [IsActive] = 0, [UpdatedAt] = SYSUTCDATETIME()
    WHERE [WorkflowId] = @WorkflowId;

    INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy])
    VALUES ('CMS_Workflows', CAST(@WorkflowId AS VARCHAR(50)), 'DELETE', @PerformedBy);
END
GO
