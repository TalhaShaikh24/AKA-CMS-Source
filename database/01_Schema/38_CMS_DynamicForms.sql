/* ============================================================================
   38_CMS_DynamicForms.sql
   Dynamic Form Builder module.
   - CMS_DynamicForms: form definitions (header).
   - CMS_DynamicFormFields: fields per form (type, options JSON, grid span,
     validation), rendered by the web renderer in the app theme.
   - Permissions: DynamicForms Read/Write (dynamic catalog, like Facilities).
   Idempotent: safe to re-run.
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[dbo].[CMS_DynamicForms]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_DynamicForms] (
        [FormId]      INT IDENTITY(1,1) NOT NULL,
        [FormKey]     VARCHAR(100) NOT NULL,
        [Title]       NVARCHAR(200) NOT NULL,
        [Description] NVARCHAR(1000) NULL,
        [IsActive]    BIT NOT NULL CONSTRAINT [DF_CMS_DynamicForms_IsActive] DEFAULT (1),
        [CreatedBy]   INT NULL,
        [CreatedAt]   DATETIME2 NOT NULL CONSTRAINT [DF_CMS_DynamicForms_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [UpdatedAt]   DATETIME2 NULL,
        CONSTRAINT [PK_CMS_DynamicForms] PRIMARY KEY CLUSTERED ([FormId]),
        CONSTRAINT [UQ_CMS_DynamicForms_FormKey] UNIQUE NONCLUSTERED ([FormKey])
    );
END
GO

IF OBJECT_ID(N'[dbo].[CMS_DynamicFormFields]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_DynamicFormFields] (
        [FieldId]     INT IDENTITY(1,1) NOT NULL,
        [FormId]      INT NOT NULL,
        [FieldKey]    VARCHAR(100) NOT NULL,
        [Label]       NVARCHAR(300) NOT NULL,
        [FieldType]   VARCHAR(30) NOT NULL,   -- text|email|number|password|textarea|select|multiselect|radio|checkboxGroup|checkbox|date|time|datetime|file|heading|paragraph
        [Placeholder] NVARCHAR(300) NULL,
        [HelpText]    NVARCHAR(500) NULL,
        [IsRequired]  BIT NOT NULL CONSTRAINT [DF_CMS_DynamicFormFields_IsRequired] DEFAULT (0),
        [DefaultValue] NVARCHAR(MAX) NULL,
        [OptionsJson] NVARCHAR(MAX) NULL,     -- [{"value":"a","label":"A"}, ...]
        [MinLength]   INT NULL,
        [MaxLength]   INT NULL,
        [MinValue]    DECIMAL(18,4) NULL,
        [MaxValue]    DECIMAL(18,4) NULL,
        [Accept]      NVARCHAR(200) NULL,     -- file input accept, e.g. .pdf,image/*
        [ChoiceLayout] VARCHAR(10) NULL,      -- radio/checkboxGroup: 'Vertical' (default) | 'Horizontal'
        [ColumnSpan]  TINYINT NOT NULL CONSTRAINT [DF_CMS_DynamicFormFields_ColumnSpan] DEFAULT (6),  -- of 12
        [SortOrder]   INT NOT NULL CONSTRAINT [DF_CMS_DynamicFormFields_SortOrder] DEFAULT (0),
        CONSTRAINT [PK_CMS_DynamicFormFields] PRIMARY KEY CLUSTERED ([FieldId]),
        CONSTRAINT [FK_CMS_DynamicFormFields_Form] FOREIGN KEY ([FormId])
            REFERENCES [dbo].[CMS_DynamicForms] ([FormId]) ON DELETE CASCADE,
        CONSTRAINT [UQ_CMS_DynamicFormFields_Form_Key] UNIQUE NONCLUSTERED ([FormId], [FieldKey])
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_DynamicFormFields_Form]
        ON [dbo].[CMS_DynamicFormFields] ([FormId], [SortOrder]);
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
        ('DynamicForms', 'Read'),
        ('DynamicForms', 'Write')
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
DECLARE @DfRead INT, @DfWrite INT;
SELECT @DfRead = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'DynamicForms' AND [ACTION] = 'Read';
SELECT @DfWrite = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'DynamicForms' AND [ACTION] = 'Write';

EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @DfRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @DfWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @DfRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @DfWrite, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = @DfRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = @DfRead, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = @DfRead, @CreatedBy = 'seed', @PerformedBy = 1;
GO

/* ---- ChoiceLayout column (radio/checkbox groups) — idempotent for DBs
   where the tables were created before this column existed ---- */
IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'ChoiceLayout') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [ChoiceLayout] VARCHAR(10) NULL;
GO
