/* ============================================================
   AKA-CMS — CMS_CommunityMembers extended patient fields
   Adds the patient-registration fields from the mobile
   "Register New Case" screen (Step 1: Personal Information).
   All columns are NULLable and additive: existing rows are untouched.
   Safe to re-run (each ADD is guarded by COL_LENGTH).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'Age') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [Age] INT NULL;
GO
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'RegionCouncil') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [RegionCouncil] NVARCHAR(100) NULL;
GO
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'LocalCouncil') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [LocalCouncil] NVARCHAR(100) NULL;
GO
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'Village') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [Village] NVARCHAR(100) NULL;
GO
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'JkAttend') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [JkAttend] NVARCHAR(100) NULL;
GO
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'EmploymentEducation') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [EmploymentEducation] NVARCHAR(200) NULL;
GO
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'MaritalStatus') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [MaritalStatus] VARCHAR(30) NULL;
GO
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'NumberOfChildren') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [NumberOfChildren] INT NULL;
GO
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'LanguagesSpoken') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [LanguagesSpoken] NVARCHAR(200) NULL;
GO
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'HealthInsurance') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [HealthInsurance] VARCHAR(50) NULL;
GO
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'GpUsualCare') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [GpUsualCare] NVARCHAR(200) NULL;
GO
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'PriorMhTreatment') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [PriorMhTreatment] VARCHAR(50) NULL;
GO
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'ConnectedToMhCare') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [ConnectedToMhCare] VARCHAR(50) NULL;
GO
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'CareProviderName') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [CareProviderName] NVARCHAR(200) NULL;
GO
