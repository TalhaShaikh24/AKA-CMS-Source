/* ============================================================================
   43_CMS_DynamicForms_SectionDisplay.sql
   Per-section display options for the Form Builder:
     ShowBorder  — the section card's border
     ShowDivider — the line under the section title
   Both are NULL-able on purpose: NULL means "default", which is SHOW for a
   top-level section and HIDE for a child (nested) section. The API/builder
   store an explicit value only once the user changes the option.
   Idempotent: safe to re-run.
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'ShowBorder') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [ShowBorder] BIT NULL;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'ShowDivider') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [ShowDivider] BIT NULL;
GO
