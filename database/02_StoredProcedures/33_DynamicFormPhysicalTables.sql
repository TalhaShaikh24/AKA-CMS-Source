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
