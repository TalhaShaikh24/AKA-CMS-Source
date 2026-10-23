/* ============================================================================
   42_CMS_DynamicForms_Nesting.sql
   Nested sections for the Form Builder: ParentKey records which section a
   field (or a section) belongs to. NULL = top level of the form. A section
   may sit inside another section's column (Elementor "inner section").
   Rows saved before this change have ParentKey NULL everywhere; the API
   derives the parent from field order for those rows (fields after a
   section belonged to it), so existing forms keep working unchanged.
   Idempotent: safe to re-run.
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'ParentKey') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [ParentKey] VARCHAR(100) NULL;
GO
