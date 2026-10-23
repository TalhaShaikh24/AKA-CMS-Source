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
