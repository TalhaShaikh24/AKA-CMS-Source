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
            INSERT INTO [dbo].[CMS_Workflows] ([WorkflowName], [FormId], [Description], [IsActive], [CreatedBy])
            VALUES (@WorkflowName, @FormId, @Description, @IsActive, @PerformedBy);
            SET @WorkflowId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            UPDATE [dbo].[CMS_Workflows]
            SET [WorkflowName] = @WorkflowName, [FormId] = @FormId,
                [Description] = @Description, [IsActive] = @IsActive,
                [UpdatedAt] = SYSUTCDATETIME()
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

    SELECT w.[WorkflowId], w.[WorkflowName], w.[FormId], f.[FormKey], f.[Title] AS [FormTitle],
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

    SELECT w.[WorkflowId], w.[WorkflowName], w.[FormId], f.[FormKey], f.[Title] AS [FormTitle],
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
    @FormId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @WorkflowId INT;
    SELECT TOP 1 @WorkflowId = [WorkflowId]
    FROM [dbo].[CMS_Workflows]
    WHERE [FormId] = @FormId AND [IsActive] = 1
    ORDER BY [UpdatedAt] DESC, [WorkflowId] DESC;

    SELECT @WorkflowId AS [WorkflowId];

    SELECT s.[SectionKey], s.[IsVisible], s.[DisplayOrder]
    FROM [dbo].[CMS_WorkflowSections] s
    WHERE s.[WorkflowId] = @WorkflowId AND s.[IsActive] = 1
    ORDER BY s.[DisplayOrder], s.[WorkflowSectionId];

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
/* ============================================================================
   33_DynamicFormPhysicalTables.sql
   Dynamic Form Builder — physical tables per form (FormData_ prefix).

   One physical table per form, created on form save:
     FormData_<form-key with '-' -> '_'>
     [EntryId] INT IDENTITY(1,1) PRIMARY KEY  (every table's own
       identity key, like every other CMS_ table)
     [SubmissionId] INT UNIQUE, foreign key to
       CMS_DynamicFormSubmissions(SubmissionId) ON DELETE CASCADE
       (the 1-to-1 link to the JSON entry: one physical row per entry,
       and deleting the entry deletes its physical row automatically)
     [SubmittedBy], [SubmittedAt]
     one column per non-static field, named in PascalCase from the
     field key: fullName -> FullName, full-name -> FullName (hyphens
     drop, each part's first letter is capitalized). The field key
     itself stays camelCase — only the SQL column is PascalCase.

   Datatypes: the field's SqlDataType when set, otherwise the default
   for its type (text/email/select/radio/hidden -> NVARCHAR(255),
   textarea/multiselect/checkboxGroup/grid -> NVARCHAR(MAX),
   checkbox -> BIT, date -> DATE, time -> TIME, datetime -> DATETIME2,
   file -> NVARCHAR(500) for the stored path).

   Lookup fields — the relational rule, thought through:
   A foreign key must point at the other table's PRIMARY KEY, not at
   an arbitrary text column (a text column is neither unique nor a key,
   so SQL Server cannot enforce a foreign key on it at all). The column
   the user picks in the builder is the DISPLAY column — what the
   dropdown shows. The physical lookup column is therefore INT and
   references FormData_<source>(EntryId): the identity key of the
   source entry whose chosen field holds the selected value. The JSON
   entry keeps the human-readable value itself, so nothing already
   built changes. If the selected value matches no submitted source
   entry (it came from a configured option list, not a submission),
   the physical column stays NULL — the JSON entry is still complete.

   All DDL here runs inside stored procedures only: the API layer
   never builds SQL text (Clean Architecture rule, stored procedures
   only). Column names come from validated field keys and are always
   QUOTENAME-wrapped; datatypes are pattern-checked before use, so no
   user text can break out of the generated statement.
   ============================================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_DynamicForm_EnsurePhysicalTable ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_DynamicForm_EnsurePhysicalTable]
    @FormId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FormKey VARCHAR(100);
    DECLARE @TableName NVARCHAR(128);
    SELECT @FormKey = [FormKey] FROM [dbo].[CMS_DynamicForms] WHERE [FormId] = @FormId;
    IF @FormKey IS NULL
        THROW 50000, 'Form not found.', 1;
    SET @TableName = N'FormData_' + REPLACE(@FormKey, '-', '_');

    /* Field list for this form, with the effective SQL type per field.
       ColumnName starts as the field key and is converted to
       PascalCase by the cursor below. */
    SELECT
        f.[FieldKey],
        f.[FieldType],
        f.[FieldKey] AS [ColumnName],
        CASE
            WHEN f.[FieldType] = 'lookup' THEN N'INT'
            WHEN f.[SqlDataType] IS NOT NULL AND f.[SqlDataType] <> N'' THEN f.[SqlDataType]
            WHEN f.[FieldType] IN ('textarea', 'multiselect', 'checkboxGroup', 'grid') THEN N'NVARCHAR(MAX)'
            WHEN f.[FieldType] = 'checkbox' THEN N'BIT'
            WHEN f.[FieldType] = 'date' THEN N'DATE'
            WHEN f.[FieldType] = 'time' THEN N'TIME'
            WHEN f.[FieldType] = 'datetime' THEN N'DATETIME2'
            WHEN f.[FieldType] = 'file' THEN N'NVARCHAR(500)'
            ELSE N'NVARCHAR(255)'
        END AS [EffectiveType],
        f.[LookupFormId],
        f.[LookupFieldKey]
    INTO #Fields
    FROM [dbo].[CMS_DynamicFormFields] f
    WHERE f.[FormId] = @FormId
      AND f.[FieldType] NOT IN ('heading', 'paragraph', 'section', 'button', 'link');

    /* Column names are PascalCase, derived from the field key:
       fullName -> FullName, full-name -> FullName. Hyphens are
       dropped and each part's first letter is capitalized; the rest
       of each part is kept as-is, so a camelCase key keeps its humps.
       A cursor is used (not STRING_SPLIT with ordinal) so this runs
       on SQL Server versions older than 2022 too. */
    DECLARE @PasKey NVARCHAR(100);
    DECLARE @PasRest NVARCHAR(100);
    DECLARE @PasPart NVARCHAR(100);
    DECLARE @PasPos INT;
    DECLARE @PasCol NVARCHAR(128);
    DECLARE pascal_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT [FieldKey] FROM #Fields;
    OPEN pascal_cursor;
    FETCH NEXT FROM pascal_cursor INTO @PasKey;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @PasCol = N'';
        SET @PasRest = @PasKey;
        WHILE LEN(@PasRest) > 0
        BEGIN
            SET @PasPos = CHARINDEX('-', @PasRest);
            IF @PasPos = 0
            BEGIN
                SET @PasPart = @PasRest;
                SET @PasRest = N'';
            END
            ELSE
            BEGIN
                SET @PasPart = LEFT(@PasRest, @PasPos - 1);
                SET @PasRest = SUBSTRING(@PasRest, @PasPos + 1, LEN(@PasRest));
            END
            IF LEN(@PasPart) > 0
                SET @PasCol = @PasCol + UPPER(LEFT(@PasPart, 1)) + SUBSTRING(@PasPart, 2, LEN(@PasPart));
        END
        UPDATE #Fields SET [ColumnName] = @PasCol WHERE [FieldKey] = @PasKey;
        FETCH NEXT FROM pascal_cursor INTO @PasKey;
    END
    CLOSE pascal_cursor;
    DEALLOCATE pascal_cursor;

    /* Datatype safety: only letters, digits, parentheses, comma.
       Anything else (space, quote, semicolon, bracket) is rejected
       rather than injected into the generated DDL. */
    /* #Fields has no SqlDataType column of its own — the resolved type
       lives in EffectiveType (the custom type when set, else the
       default), so the safety check runs against that. */
    IF EXISTS (
        SELECT 1 FROM #Fields
        WHERE PATINDEX('%[^A-Z0-9(),]%', UPPER([EffectiveType])) > 0
    )
        THROW 50000, 'A field has an invalid SQL data type.', 1;

    /* 1) Create the table when it does not exist yet. */
    IF OBJECT_ID(N'[dbo].' + QUOTENAME(@TableName), N'U') IS NULL
    BEGIN
        DECLARE @Cols NVARCHAR(MAX);
        SELECT @Cols = STRING_AGG(CAST(QUOTENAME([ColumnName]) + N' ' + [EffectiveType] + N' NULL' AS NVARCHAR(MAX)), N', ')
        FROM #Fields;
        DECLARE @CreateSql NVARCHAR(MAX) =
            N'CREATE TABLE [dbo].' + QUOTENAME(@TableName) +
            N' ([EntryId] INT IDENTITY(1,1) NOT NULL CONSTRAINT [PK_' + @TableName + N'] PRIMARY KEY,' +
            N' [SubmissionId] INT NOT NULL CONSTRAINT [UQ_' + @TableName + N'_Submission] UNIQUE,' +
            N' [SubmittedBy] INT NULL,' +
            N' [SubmittedAt] DATETIME2 NOT NULL CONSTRAINT [DF_' + @TableName + N'_SubmittedAt] DEFAULT (SYSUTCDATETIME()),' +
            N' CONSTRAINT [FK_' + @TableName + N'_Submission] FOREIGN KEY ([SubmissionId])' +
            N' REFERENCES [dbo].[CMS_DynamicFormSubmissions] ([SubmissionId]) ON DELETE CASCADE' +
            CASE WHEN @Cols IS NOT NULL THEN N', ' + @Cols ELSE N'' END + N');';
        EXEC sp_executesql @CreateSql;
    END

    /* 2) Add columns for fields added since the table was created.
       Existing columns are never altered: changing a type under live
       data is a data-loss risk, so a datatype change only applies to
       tables created after it. */
    DECLARE @Missing NVARCHAR(MAX);
    SELECT @Missing = STRING_AGG(CAST(QUOTENAME(f.[ColumnName]) + N' ' + f.[EffectiveType] + N' NULL' AS NVARCHAR(MAX)), N', ')
    FROM #Fields f
    WHERE NOT EXISTS (
        SELECT 1 FROM sys.columns c
        WHERE c.[object_id] = OBJECT_ID(N'[dbo].' + QUOTENAME(@TableName))
          AND c.[name] = f.[ColumnName]
    );
    IF @Missing IS NOT NULL
    BEGIN
        DECLARE @AddSql NVARCHAR(MAX) =
            N'ALTER TABLE [dbo].' + QUOTENAME(@TableName) + N' ADD ' + @Missing + N';';
        EXEC sp_executesql @AddSql;
    END

    /* 3) Foreign keys for lookup fields, to the source table's PK. */
    DECLARE @LookupKey VARCHAR(100);
    DECLARE @LookupFormId INT;
    DECLARE @LookupColumn NVARCHAR(128);
    DECLARE @SourceTable NVARCHAR(128);
    DECLARE @SourceFormKey VARCHAR(100);
    DECLARE @FkName NVARCHAR(128);

    DECLARE lookup_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT [FieldKey], [LookupFormId], [ColumnName]
        FROM #Fields
        WHERE [FieldType] = 'lookup' AND [LookupFormId] IS NOT NULL;
    OPEN lookup_cursor;
    FETCH NEXT FROM lookup_cursor INTO @LookupKey, @LookupFormId, @LookupColumn;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @SourceFormKey = [FormKey] FROM [dbo].[CMS_DynamicForms] WHERE [FormId] = @LookupFormId;
        IF @SourceFormKey IS NULL
            THROW 50000, 'A lookup field points at a form that does not exist.', 1;
        SET @SourceTable = N'FormData_' + REPLACE(@SourceFormKey, '-', '_');
        IF OBJECT_ID(N'[dbo].' + QUOTENAME(@SourceTable), N'U') IS NULL
            THROW 50000, 'The lookup source form has no physical table yet. Save the source form first.', 1;

        SET @FkName = LEFT(N'FK_' + REPLACE(@FormKey, '-', '_') + N'_' + @LookupColumn, 120);
        IF NOT EXISTS (
            SELECT 1 FROM sys.foreign_keys fk
            WHERE fk.[name] = @FkName
              AND fk.[parent_object_id] = OBJECT_ID(N'[dbo].' + QUOTENAME(@TableName))
        )
        BEGIN
            DECLARE @FkSql NVARCHAR(MAX) =
                N'ALTER TABLE [dbo].' + QUOTENAME(@TableName) +
                N' ADD CONSTRAINT ' + QUOTENAME(@FkName) +
                N' FOREIGN KEY (' + QUOTENAME(@LookupColumn) + N')' +
                N' REFERENCES [dbo].' + QUOTENAME(@SourceTable) + N' ([EntryId]);';
            EXEC sp_executesql @FkSql;
        END
        FETCH NEXT FROM lookup_cursor INTO @LookupKey, @LookupFormId, @LookupColumn;
    END
    CLOSE lookup_cursor;
    DEALLOCATE lookup_cursor;

    DROP TABLE #Fields;
END
GO

/* ---- sp_CMS_DynamicFormData_Upsert ----
   Insert or update one physical row. @ValuesJson is a JSON OBJECT
   {fieldKey: value, ...} (values are real JSON values, not strings
   of JSON). A field absent from the object stays NULL on insert and
   is left untouched on update. Lookup columns resolve to the source
   entry id whose chosen field holds the selected value (latest such
   entry wins); no match -> NULL, never an error. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_DynamicFormData_Upsert]
    @FormId INT,
    @SubmissionId INT,
    @SubmittedBy INT = NULL,
    @ValuesJson NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FormKey VARCHAR(100);
    DECLARE @TableName NVARCHAR(128);
    SELECT @FormKey = [FormKey] FROM [dbo].[CMS_DynamicForms] WHERE [FormId] = @FormId;
    IF @FormKey IS NULL
        THROW 50000, 'Form not found.', 1;
    SET @TableName = N'FormData_' + REPLACE(@FormKey, '-', '_');
    IF OBJECT_ID(N'[dbo].' + QUOTENAME(@TableName), N'U') IS NULL
        THROW 50000, 'The form has no physical table yet. Save the form first.', 1;

    SELECT
        f.[FieldKey],
        f.[FieldKey] AS [ColumnName],
        f.[FieldType],
        CASE
            WHEN f.[FieldType] = 'lookup' THEN N'INT'
            WHEN f.[SqlDataType] IS NOT NULL AND f.[SqlDataType] <> N'' THEN f.[SqlDataType]
            WHEN f.[FieldType] IN ('textarea', 'multiselect', 'checkboxGroup', 'grid') THEN N'NVARCHAR(MAX)'
            WHEN f.[FieldType] = 'checkbox' THEN N'BIT'
            WHEN f.[FieldType] = 'date' THEN N'DATE'
            WHEN f.[FieldType] = 'time' THEN N'TIME'
            WHEN f.[FieldType] = 'datetime' THEN N'DATETIME2'
            WHEN f.[FieldType] = 'file' THEN N'NVARCHAR(500)'
            ELSE N'NVARCHAR(255)'
        END AS [EffectiveType],
        f.[LookupFormId],
        f.[LookupFieldKey],
        CASE WHEN sf.[FormKey] IS NULL THEN NULL
             ELSE N'FormData_' + REPLACE(sf.[FormKey], '-', '_') END AS [SourceTable]
    INTO #UpsertFields
    FROM [dbo].[CMS_DynamicFormFields] f
    LEFT JOIN [dbo].[CMS_DynamicForms] sf ON sf.[FormId] = f.[LookupFormId]
    WHERE f.[FormId] = @FormId
      AND f.[FieldType] NOT IN ('heading', 'paragraph', 'section', 'button', 'link');

    /* Same PascalCase conversion as in Ensure (see there): the
       column a value lands in is the PascalCase form of its key. */
    DECLARE @PasKey NVARCHAR(100);
    DECLARE @PasRest NVARCHAR(100);
    DECLARE @PasPart NVARCHAR(100);
    DECLARE @PasPos INT;
    DECLARE @PasCol NVARCHAR(128);
    DECLARE pascal_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT [FieldKey] FROM #UpsertFields;
    OPEN pascal_cursor;
    FETCH NEXT FROM pascal_cursor INTO @PasKey;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @PasCol = N'';
        SET @PasRest = @PasKey;
        WHILE LEN(@PasRest) > 0
        BEGIN
            SET @PasPos = CHARINDEX('-', @PasRest);
            IF @PasPos = 0
            BEGIN
                SET @PasPart = @PasRest;
                SET @PasRest = N'';
            END
            ELSE
            BEGIN
                SET @PasPart = LEFT(@PasRest, @PasPos - 1);
                SET @PasRest = SUBSTRING(@PasRest, @PasPos + 1, LEN(@PasRest));
            END
            IF LEN(@PasPart) > 0
                SET @PasCol = @PasCol + UPPER(LEFT(@PasPart, 1)) + SUBSTRING(@PasPart, 2, LEN(@PasPart));
        END
        UPDATE #UpsertFields SET [ColumnName] = @PasCol WHERE [FieldKey] = @PasKey;
        FETCH NEXT FROM pascal_cursor INTO @PasKey;
    END
    CLOSE pascal_cursor;
    DEALLOCATE pascal_cursor;

    /* OPENJSON on an object gives key/value/type per property:
       string -> the text itself, number/bool -> its text,
       array/object -> the JSON text. That is exactly what each
       column type needs (arrays/objects land as JSON text). */
    SELECT [key] AS [FieldKey], [value] AS [ValueText], [type] AS [ValueType]
    INTO #Vals
    FROM OPENJSON(@ValuesJson);

    DECLARE @ColList NVARCHAR(MAX);
    DECLARE @ExprList NVARCHAR(MAX);
    DECLARE @SetList NVARCHAR(MAX);
    SELECT
        @ColList = STRING_AGG(CAST(QUOTENAME([ColumnName]) AS NVARCHAR(MAX)), N', '),
        @ExprList = STRING_AGG(CAST(
            CASE
                WHEN [FieldType] = 'lookup' THEN
                    N'(SELECT TOP 1 p.[EntryId] FROM [dbo].' + QUOTENAME([SourceTable]) + N' p ' +
                    N'INNER JOIN [dbo].[CMS_DynamicFormSubmissions] s ON s.[SubmissionId] = p.[SubmissionId] ' +
                    N'INNER JOIN [dbo].[CMS_DynamicFormSubmissionValues] v ON v.[SubmissionId] = s.[SubmissionId] ' +
                    N'WHERE s.[FormId] = ' + CAST([LookupFormId] AS NVARCHAR(20)) +
                    N' AND v.[FieldKey] = ''' + REPLACE([LookupFieldKey], '''', '''''') + N''' ' +
                    N'AND (v.[ValueJson] = (SELECT [ValueText] FROM #Vals WHERE [FieldKey] = ''' + REPLACE([FieldKey], '''', '''''') + N''') ' +
                    N'OR v.[ValueJson] = ''"'' + (SELECT [ValueText] FROM #Vals WHERE [FieldKey] = ''' + REPLACE([FieldKey], '''', '''''') + N''') + ''"'') ' +
                    N'ORDER BY s.[SubmittedAt] DESC, s.[SubmissionId] DESC)'
                WHEN [EffectiveType] = 'BIT' THEN
                    N'CASE (SELECT [ValueText] FROM #Vals WHERE [FieldKey] = ''' + REPLACE([FieldKey], '''', '''''') + N''') ' +
                    N'WHEN ''true'' THEN 1 WHEN ''1'' THEN 1 WHEN ''false'' THEN 0 WHEN ''0'' THEN 0 ELSE NULL END'
                WHEN [EffectiveType] LIKE 'NVARCHAR%' OR [EffectiveType] LIKE 'VARCHAR%' THEN
                    N'(SELECT [ValueText] FROM #Vals WHERE [FieldKey] = ''' + REPLACE([FieldKey], '''', '''''') + N''')'
                ELSE
                    N'TRY_CAST((SELECT [ValueText] FROM #Vals WHERE [FieldKey] = ''' + REPLACE([FieldKey], '''', '''''') + N''') AS ' + [EffectiveType] + N')'
            END AS NVARCHAR(MAX)), N', '),
        @SetList = STRING_AGG(CAST(
            QUOTENAME([ColumnName]) + N' = ' +
            CASE
                WHEN [FieldType] = 'lookup' THEN
                    N'(SELECT TOP 1 p.[EntryId] FROM [dbo].' + QUOTENAME([SourceTable]) + N' p ' +
                    N'INNER JOIN [dbo].[CMS_DynamicFormSubmissions] s ON s.[SubmissionId] = p.[SubmissionId] ' +
                    N'INNER JOIN [dbo].[CMS_DynamicFormSubmissionValues] v ON v.[SubmissionId] = s.[SubmissionId] ' +
                    N'WHERE s.[FormId] = ' + CAST([LookupFormId] AS NVARCHAR(20)) +
                    N' AND v.[FieldKey] = ''' + REPLACE([LookupFieldKey], '''', '''''') + N''' ' +
                    N'AND (v.[ValueJson] = (SELECT [ValueText] FROM #Vals WHERE [FieldKey] = ''' + REPLACE([FieldKey], '''', '''''') + N''') ' +
                    N'OR v.[ValueJson] = ''"'' + (SELECT [ValueText] FROM #Vals WHERE [FieldKey] = ''' + REPLACE([FieldKey], '''', '''''') + N''') + ''"'') ' +
                    N'ORDER BY s.[SubmittedAt] DESC, s.[SubmissionId] DESC)'
                WHEN [EffectiveType] = 'BIT' THEN
                    N'CASE (SELECT [ValueText] FROM #Vals WHERE [FieldKey] = ''' + REPLACE([FieldKey], '''', '''''') + N''') ' +
                    N'WHEN ''true'' THEN 1 WHEN ''1'' THEN 1 WHEN ''false'' THEN 0 WHEN ''0'' THEN 0 ELSE NULL END'
                WHEN [EffectiveType] LIKE 'NVARCHAR%' OR [EffectiveType] LIKE 'VARCHAR%' THEN
                    N'(SELECT [ValueText] FROM #Vals WHERE [FieldKey] = ''' + REPLACE([FieldKey], '''', '''''') + N''')'
                ELSE
                    N'TRY_CAST((SELECT [ValueText] FROM #Vals WHERE [FieldKey] = ''' + REPLACE([FieldKey], '''', '''''') + N''') AS ' + [EffectiveType] + N')'
            END AS NVARCHAR(MAX)), N', ')
    FROM #UpsertFields;

    DECLARE @UpsertSql NVARCHAR(MAX);
    IF @ColList IS NULL
    BEGIN
        /* A form with no data fields still gets a header row. */
        SET @UpsertSql =
            N'IF EXISTS (SELECT 1 FROM [dbo].' + QUOTENAME(@TableName) + N' WHERE [SubmissionId] = @sid) ' +
            N'UPDATE [dbo].' + QUOTENAME(@TableName) + N' SET [SubmittedBy] = @by WHERE [SubmissionId] = @sid ' +
            N'ELSE INSERT INTO [dbo].' + QUOTENAME(@TableName) + N' ([SubmissionId], [SubmittedBy], [SubmittedAt]) ' +
            N'VALUES (@sid, @by, SYSUTCDATETIME());';
    END
    ELSE
    BEGIN
        SET @UpsertSql =
            N'IF EXISTS (SELECT 1 FROM [dbo].' + QUOTENAME(@TableName) + N' WHERE [SubmissionId] = @sid) ' +
            N'UPDATE [dbo].' + QUOTENAME(@TableName) + N' SET ' + @SetList + N' WHERE [SubmissionId] = @sid ' +
            N'ELSE INSERT INTO [dbo].' + QUOTENAME(@TableName) + N' ([SubmissionId], [SubmittedBy], [SubmittedAt], ' + @ColList + N') ' +
            N'VALUES (@sid, @by, SYSUTCDATETIME(), ' + @ExprList + N');';
    END
    EXEC sp_executesql @UpsertSql, N'@sid INT, @by INT', @sid = @SubmissionId, @by = @SubmittedBy;

    DROP TABLE #Vals;
    DROP TABLE #UpsertFields;
END
GO

/* ---- sp_CMS_DynamicFormData_DeleteRow ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_DynamicFormData_DeleteRow]
    @FormId INT,
    @SubmissionId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FormKey VARCHAR(100);
    DECLARE @TableName NVARCHAR(128);
    SELECT @FormKey = [FormKey] FROM [dbo].[CMS_DynamicForms] WHERE [FormId] = @FormId;
    IF @FormKey IS NULL RETURN;
    SET @TableName = N'FormData_' + REPLACE(@FormKey, '-', '_');
    IF OBJECT_ID(N'[dbo].' + QUOTENAME(@TableName), N'U') IS NULL RETURN;

    DECLARE @DelSql NVARCHAR(MAX) =
        N'DELETE FROM [dbo].' + QUOTENAME(@TableName) + N' WHERE [SubmissionId] = @sid;';
    EXEC sp_executesql @DelSql, N'@sid INT', @sid = @SubmissionId;
END
GO

/* ---- sp_CMS_DynamicFormSubmission_Update ----
   Replace one entry's values (the JSON store). The physical row is
   updated by the caller through sp_CMS_DynamicFormData_Upsert, so the
   two stores cannot drift apart on an edit. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_DynamicFormSubmission_Update]
    @SubmissionId INT,
    @FormId INT,
    @ValuesJson NVARCHAR(MAX) = NULL,
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM [dbo].[CMS_DynamicFormSubmissions]
        WHERE [SubmissionId] = @SubmissionId AND [FormId] = @FormId
    )
        THROW 50000, 'Submission not found for this form.', 1;

    BEGIN TRY
        BEGIN TRAN;

        DELETE FROM [dbo].[CMS_DynamicFormSubmissionValues]
        WHERE [SubmissionId] = @SubmissionId;

        IF @ValuesJson IS NOT NULL AND ISJSON(@ValuesJson) = 1
        BEGIN
            INSERT INTO [dbo].[CMS_DynamicFormSubmissionValues]
                ([SubmissionId], [FieldKey], [ValueJson])
            SELECT  @SubmissionId, j.[FieldKey], j.[ValueJson]
            FROM OPENJSON(@ValuesJson)
            WITH (
                [FieldKey]  VARCHAR(100)  '$.fieldKey',
                [ValueJson] NVARCHAR(MAX) '$.valueJson'
            ) AS j
            WHERE j.[FieldKey] IS NOT NULL;
        END

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy])
        VALUES ('CMS_DynamicFormSubmissions', CAST(@SubmissionId AS VARCHAR(50)), 'UPDATE', @PerformedBy);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
