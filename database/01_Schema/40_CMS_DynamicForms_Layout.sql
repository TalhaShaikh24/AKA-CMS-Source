/* ============================================================================
   40_CMS_DynamicForms_Layout.sql
   Elementor-style section layout for the Form Builder:
   - SectionColumns (on 'section' fields): how many columns the section
     has (1-4). NULL = legacy mode (fields flow in the 12-column span
     grid, exactly as before this change).
   - ColumnIndex (on fields inside such a section): which column of the
     section the field sits in (0-based). NULL = first column.
   Idempotent: safe to re-run.
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'SectionColumns') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [SectionColumns] TINYINT NULL;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'ColumnIndex') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [ColumnIndex] TINYINT NULL;
GO
