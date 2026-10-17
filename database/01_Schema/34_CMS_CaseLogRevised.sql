/* ============================================================================
   34_CMS_CaseLogRevised.sql
   Case Log Revised (DHRC 210926) — field changes
   - CMS_CommunityMembers: FirstName/LastName split, DateOfCall, EntryPoint,
     ReturningCaller, ConsentToProceed
   - New table CMS_CaseRiskAssessments: structured risk assessment per case
   Idempotent: safe to re-run.
   ============================================================================ */

-- ---------- 1. New columns on CMS_CommunityMembers ----------
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'FirstName') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [FirstName] NVARCHAR(100) NULL;
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'LastName') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [LastName] NVARCHAR(100) NULL;
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'DateOfCall') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [DateOfCall] DATE NULL;
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'EntryPoint') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [EntryPoint] VARCHAR(50) NULL;
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'ReturningCaller') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [ReturningCaller] VARCHAR(50) NULL;
IF COL_LENGTH(N'[dbo].[CMS_CommunityMembers]', N'ConsentToProceed') IS NULL
    ALTER TABLE [dbo].[CMS_CommunityMembers] ADD [ConsentToProceed] VARCHAR(50) NULL;
GO

-- Backfill FirstName/LastName from existing FullName (first token / rest).
UPDATE [dbo].[CMS_CommunityMembers]
SET [FirstName] = CASE WHEN CHARINDEX(' ', LTRIM(RTRIM([FullName]))) > 0
                       THEN LEFT(LTRIM(RTRIM([FullName])), CHARINDEX(' ', LTRIM(RTRIM([FullName]))) - 1)
                       ELSE LTRIM(RTRIM([FullName])) END,
    [LastName]  = CASE WHEN CHARINDEX(' ', LTRIM(RTRIM([FullName]))) > 0
                       THEN LTRIM(SUBSTRING(LTRIM(RTRIM([FullName])), CHARINDEX(' ', LTRIM(RTRIM([FullName]))) + 1, 200))
                       ELSE NULL END
WHERE [FirstName] IS NULL AND [FullName] IS NOT NULL;
GO

-- ---------- 2. CMS_CaseRiskAssessments ----------
IF OBJECT_ID(N'[dbo].[CMS_CaseRiskAssessments]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_CaseRiskAssessments] (
        [AssessmentId]            INT IDENTITY(1,1) NOT NULL,
        [CaseId]                  INT NOT NULL,
        [PresentingConcern]       NVARCHAR(2000) NULL,
        [PrimaryMhIssue]          VARCHAR(100) NULL,
        [PrimaryMhIssueOther]     NVARCHAR(200) NULL,
        [IsCrisis]                VARCHAR(50) NULL,
        [CrisisType]              VARCHAR(50) NULL,
        [RiskCategory]            VARCHAR(30) NULL,
        [SuicidalIdeation]        VARCHAR(60) NULL,
        [SelfHarmRisk]            VARCHAR(30) NULL,
        [ViolenceRisk]            VARCHAR(30) NULL,
        [SeverityImmediacy]       VARCHAR(50) NULL,
        [AccessToMeans]           VARCHAR(20) NULL,
        [SafeguardingConcerns]    NVARCHAR(1000) NULL,
        [PreviousAttempts]        NVARCHAR(1000) NULL,
        [CurrentSupports]         NVARCHAR(1000) NULL,
        [ProtectiveFactors]       NVARCHAR(1000) NULL,
        [BarriersToCare]          NVARCHAR(1000) NULL,
        [SafetyPlanFilled]        VARCHAR(20) NULL,
        [SocialDeterminantIssues] NVARCHAR(500) NULL,
        [SocialDeterminantOther]  NVARCHAR(200) NULL,
        [SupervisorNotified]      VARCHAR(10) NULL,
        [SupervisorNotifiedAt]    DATETIME2 NULL,
        [AssessorName]            NVARCHAR(200) NULL,
        [AssessedAt]              DATETIME2 NULL,
        [CreatedBy]               INT NOT NULL,
        [CreatedAt]               DATETIME2 NOT NULL CONSTRAINT [DF_CMS_CaseRiskAssessments_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [ModifiedBy]              INT NULL,
        [ModifiedAt]              DATETIME2 NULL,
        CONSTRAINT [PK_CMS_CaseRiskAssessments] PRIMARY KEY CLUSTERED ([AssessmentId]),
        CONSTRAINT [FK_CMS_CaseRiskAssessments_Case]
            FOREIGN KEY ([CaseId]) REFERENCES [dbo].[CMS_Cases]([CaseId])
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_CaseRiskAssessments_CaseId]
        ON [dbo].[CMS_CaseRiskAssessments] ([CaseId]);
END
GO
