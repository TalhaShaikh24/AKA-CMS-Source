/* ============================================================================
   AKA-CMS DB Update — 2026-10-23 — Form Builder: advanced field options
   (custom JS, CSS class, custom ID, custom attributes, multiple regex
   rules, input mask, info icon). Run order: (1) schema 41, (2) SP 30.
   Every section is idempotent — the whole file is safe to re-run.
   ============================================================================ */

/* ================= PART 1: 41_CMS_DynamicForms_Advanced.sql ================= */
/* ============================================================================
   41_CMS_DynamicForms_Advanced.sql
   Advanced per-field options for the Form Builder:
   - CustomJs            : custom JavaScript run when the field changes
                           (or the button is clicked).
   - CssClass            : extra CSS class(es) on the field wrapper.
   - CustomId            : custom element id for the field control.
   - CustomAttributesJson: extra attributes [{name, value}] for the control.
   - ValidationRulesJson : extra regex rules [{pattern, message}] — in
                           addition to the single RegexPattern column.
   - InputMask           : input mask pattern (9 = digit, a = letter,
                           * = any alphanumeric; other chars are literals).
   - ShowInfoIcon        : show an info (i) icon next to the label.
   - InfoText            : the info message shown in the icon's tooltip.
   Idempotent: safe to re-run.
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'CustomJs') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [CustomJs] NVARCHAR(MAX) NULL;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'CssClass') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [CssClass] NVARCHAR(200) NULL;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'CustomId') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [CustomId] VARCHAR(100) NULL;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'CustomAttributesJson') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [CustomAttributesJson] NVARCHAR(MAX) NULL;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'ValidationRulesJson') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [ValidationRulesJson] NVARCHAR(MAX) NULL;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'InputMask') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [InputMask] NVARCHAR(100) NULL;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'ShowInfoIcon') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields]
        ADD [ShowInfoIcon] BIT NOT NULL CONSTRAINT [DF_CMS_DynamicFormFields_ShowInfoIcon] DEFAULT (0);
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'InfoText') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [InfoText] NVARCHAR(500) NULL;
GO

/* ================= PART 2: 30_DynamicForms.sql (re-run) ================= */
/* ============================================================================
   30_DynamicForms.sql
   Dynamic Form Builder stored procedures.
   Save = upsert header + full field replace; fields arrive as one JSON
   document (@FieldsJson) parsed with OPENJSON.
   ============================================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_DynamicForm_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_DynamicForm_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  f.[FormId], f.[FormKey], f.[Title], f.[Description], f.[IsActive], f.[IsMultiStep],
            f.[CreatedAt], f.[UpdatedAt],
            (SELECT COUNT(*) FROM [dbo].[CMS_DynamicFormFields] ff
             WHERE ff.[FormId] = f.[FormId]) AS [FieldCount]
    FROM [dbo].[CMS_DynamicForms] f
    ORDER BY f.[Title];
END
GO

/* ---- sp_CMS_DynamicForm_GetById (form + fields) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_DynamicForm_GetById]
    @FormId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  f.[FormId], f.[FormKey], f.[Title], f.[Description], f.[IsActive], f.[IsMultiStep],
            f.[CreatedAt], f.[UpdatedAt],
            (SELECT COUNT(*) FROM [dbo].[CMS_DynamicFormFields] ff
             WHERE ff.[FormId] = f.[FormId]) AS [FieldCount]
    FROM [dbo].[CMS_DynamicForms] f
    WHERE f.[FormId] = @FormId;

    SELECT  [FieldId], [FormId], [FieldKey], [Label], [FieldType], [Placeholder],
            [HelpText], [IsRequired], [DefaultValue], [OptionsJson],
            [MinLength], [MaxLength], [MinValue], [MaxValue], [Accept],
            [ChoiceLayout], [ButtonAction], [RegexPattern], [ValidationMessage],
            [LookupFormId], [LookupFieldKey], [SectionColumns], [ColumnIndex],
            [CustomJs], [CssClass], [CustomId], [CustomAttributesJson],
            [ValidationRulesJson], [InputMask], [ShowInfoIcon], [InfoText],
            [ColumnSpan], [SortOrder]
    FROM [dbo].[CMS_DynamicFormFields]
    WHERE [FormId] = @FormId
    ORDER BY [SortOrder], [FieldId];
END
GO

/* ---- sp_CMS_DynamicForm_Save ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_DynamicForm_Save]
    @FormId INT = 0,                    -- 0 = create
    @FormKey VARCHAR(100),
    @Title NVARCHAR(200),
    @Description NVARCHAR(1000) = NULL,
    @IsActive BIT = 1,
    @IsMultiStep BIT = 0,
    @FieldsJson NVARCHAR(MAX) = NULL,   -- array of field objects
    @PerformedBy INT,
    @NewFormId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF @FormId = 0
        BEGIN
            INSERT INTO [dbo].[CMS_DynamicForms] ([FormKey], [Title], [Description], [IsActive], [IsMultiStep], [CreatedBy])
            VALUES (@FormKey, @Title, @Description, @IsActive, @IsMultiStep, @PerformedBy);
            SET @NewFormId = CAST(SCOPE_IDENTITY() AS INT);
        END
        ELSE
        BEGIN
            UPDATE [dbo].[CMS_DynamicForms]
            SET [FormKey] = @FormKey, [Title] = @Title, [Description] = @Description,
                [IsActive] = @IsActive, [IsMultiStep] = @IsMultiStep, [UpdatedAt] = SYSUTCDATETIME()
            WHERE [FormId] = @FormId;
            SET @NewFormId = @FormId;

            DELETE FROM [dbo].[CMS_DynamicFormFields] WHERE [FormId] = @FormId;
        END

        IF @FieldsJson IS NOT NULL AND ISJSON(@FieldsJson) = 1
        BEGIN
            INSERT INTO [dbo].[CMS_DynamicFormFields]
                ([FormId], [FieldKey], [Label], [FieldType], [Placeholder], [HelpText],
                 [IsRequired], [DefaultValue], [OptionsJson], [MinLength], [MaxLength],
                 [MinValue], [MaxValue], [Accept], [ChoiceLayout], [ButtonAction],
                 [RegexPattern], [ValidationMessage], [LookupFormId], [LookupFieldKey],
                 [SectionColumns], [ColumnIndex], [CustomJs], [CssClass], [CustomId],
                 [CustomAttributesJson], [ValidationRulesJson], [InputMask],
                 [ShowInfoIcon], [InfoText], [ColumnSpan], [SortOrder])
            SELECT  @NewFormId,
                    j.[FieldKey], j.[Label], j.[FieldType], j.[Placeholder], j.[HelpText],
                    ISNULL(j.[IsRequired], 0), j.[DefaultValue], j.[OptionsJson],
                    j.[MinLength], j.[MaxLength], j.[MinValue], j.[MaxValue], j.[Accept],
                    j.[ChoiceLayout], j.[ButtonAction], j.[RegexPattern], j.[ValidationMessage],
                    j.[LookupFormId], j.[LookupFieldKey], j.[SectionColumns], j.[ColumnIndex],
                    j.[CustomJs], j.[CssClass], j.[CustomId], j.[CustomAttributesJson],
                    j.[ValidationRulesJson], j.[InputMask], ISNULL(j.[ShowInfoIcon], 0),
                    j.[InfoText],
                    ISNULL(j.[ColumnSpan], 6), ISNULL(j.[SortOrder], 0)
            FROM OPENJSON(@FieldsJson)
            WITH (
                [FieldKey]    VARCHAR(100)  '$.fieldKey',
                [Label]       NVARCHAR(300) '$.label',
                [FieldType]   VARCHAR(30)   '$.fieldType',
                [Placeholder] NVARCHAR(300) '$.placeholder',
                [HelpText]    NVARCHAR(500) '$.helpText',
                [IsRequired]  BIT           '$.isRequired',
                [DefaultValue] NVARCHAR(MAX) '$.defaultValue',
                [OptionsJson] NVARCHAR(MAX) '$.optionsJson' AS JSON,
                [MinLength]   INT           '$.minLength',
                [MaxLength]   INT           '$.maxLength',
                [MinValue]    DECIMAL(18,4) '$.minValue',
                [MaxValue]    DECIMAL(18,4) '$.maxValue',
                [Accept]      NVARCHAR(200) '$.accept',
                [ChoiceLayout] VARCHAR(10)  '$.choiceLayout',
                [ButtonAction] VARCHAR(20)  '$.buttonAction',
                [RegexPattern] NVARCHAR(500) '$.regexPattern',
                [ValidationMessage] NVARCHAR(300) '$.validationMessage',
                [LookupFormId] INT          '$.lookupFormId',
                [LookupFieldKey] VARCHAR(100) '$.lookupFieldKey',
                [SectionColumns] TINYINT    '$.sectionColumns',
                [ColumnIndex] TINYINT       '$.columnIndex',
                [CustomJs]    NVARCHAR(MAX) '$.customJs',
                [CssClass]    NVARCHAR(200) '$.cssClass',
                [CustomId]    VARCHAR(100)  '$.customId',
                [CustomAttributesJson] NVARCHAR(MAX) '$.customAttributesJson' AS JSON,
                [ValidationRulesJson] NVARCHAR(MAX) '$.validationRulesJson' AS JSON,
                [InputMask]   NVARCHAR(100) '$.inputMask',
                [ShowInfoIcon] BIT          '$.showInfoIcon',
                [InfoText]    NVARCHAR(500) '$.infoText',
                [ColumnSpan]  TINYINT       '$.columnSpan',
                [SortOrder]   INT           '$.sortOrder'
            ) AS j
            WHERE j.[FieldKey] IS NOT NULL AND j.[FieldType] IS NOT NULL;
        END

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_DynamicForms', CAST(@NewFormId AS VARCHAR(50)),
                CASE WHEN @FormId = 0 THEN 'INSERT' ELSE 'UPDATE' END, @PerformedBy, @FormKey);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_DynamicForm_Delete (soft) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_DynamicForm_Delete]
    @FormId INT,
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE [dbo].[CMS_DynamicForms]
    SET [IsActive] = 0, [UpdatedAt] = SYSUTCDATETIME()
    WHERE [FormId] = @FormId;

    INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy])
    VALUES ('CMS_DynamicForms', CAST(@FormId AS VARCHAR(50)), 'DELETE', @PerformedBy);
END
GO
