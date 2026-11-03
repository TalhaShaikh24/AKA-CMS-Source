/* ============================================================================
   45_CMS_DynamicFormPhysicalTables.sql
   Dynamic Form Builder — physical tables per form (FormData_ prefix).
   - CMS_DynamicFormFields.SqlDataType: the SQL Server type chosen for
     this field in its form's physical table (NULL = auto default by
     field type). Lookup fields do NOT use their own value: their type
     is forced to the source field's type, because a foreign key needs
     the same type on both sides.
   Idempotent: safe to re-run.
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'SqlDataType') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [SqlDataType] NVARCHAR(50) NULL;
GO
