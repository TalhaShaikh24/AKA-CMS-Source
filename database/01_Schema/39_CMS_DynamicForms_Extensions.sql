/* ============================================================================
   39_CMS_DynamicForms_Extensions.sql
   Form Builder extensions:
   - CMS_DynamicForms.IsMultiStep      — step (wizard) forms; each Section
                                         becomes a step.
   - Fields get: ButtonAction (button fields: submit|reset|button),
     RegexPattern + ValidationMessage (custom regex validation),
     LookupFormId + LookupFieldKey (SharePoint-style lookup into another
     form's field). Grid/Table columns live in OptionsJson as
     [{key,label,type,options}] for the 'grid' field type.
   New field types: section, button, hidden, grid, lookup.
   Idempotent: safe to re-run.
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH('dbo.CMS_DynamicForms', 'IsMultiStep') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicForms]
        ADD [IsMultiStep] BIT NOT NULL CONSTRAINT [DF_CMS_DynamicForms_IsMultiStep] DEFAULT (0);
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'ButtonAction') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [ButtonAction] VARCHAR(20) NULL;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'RegexPattern') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [RegexPattern] NVARCHAR(500) NULL;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'ValidationMessage') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [ValidationMessage] NVARCHAR(300) NULL;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'LookupFormId') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [LookupFormId] INT NULL;
GO

IF COL_LENGTH('dbo.CMS_DynamicFormFields', 'LookupFieldKey') IS NULL
    ALTER TABLE [dbo].[CMS_DynamicFormFields] ADD [LookupFieldKey] VARCHAR(100) NULL;
GO
