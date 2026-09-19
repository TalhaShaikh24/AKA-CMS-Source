/* ============================================================================
   AKA-CMS — Sprint 7 (Module 6: Follow-Up, LTFU, Closure, Supervision)
   Tables: CMS_FollowUps, CMS_LostToFollowUps, CMS_CaseClosures,
           CMS_SupervisionLogs, CMS_SystemSettings.

   Only CMS_-prefixed objects. Existing CO-HIS tables are never altered.
   Workflow mapping (wireframing Figure 3 / sheet):
     S32 Schedule Follow-Ups | S33 Follow-Up Attended? -> S33a Continue /
       S33b Mark LTFU (system) -> S33c supervisor alert -> S33d re-engagement
     S34 Treatment Completed? -> S34a Symptom Remission? gate ->
       S34b Clinical Supervisor Approval -> closure -> S35
     S37 Ongoing clinical and case supervision.
   LTFU threshold default (1 missed follow-up) follows S33b; it is seeded
   in CMS_SystemSettings as client-confirmable.
   ============================================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- Follow-up visits scheduled against a case ---- */
IF OBJECT_ID(N'[dbo].[CMS_FollowUps]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_FollowUps] (
        [FollowUpId]        INT            IDENTITY(1,1) NOT NULL,
        [CaseId]            INT            NOT NULL,
        [ScheduledDate]     DATETIME2      NOT NULL,
        [ActualDate]        DATETIME2      NULL,
        [FollowUpType]      VARCHAR(40)    NOT NULL, -- SCHEDULED / QUARTERLY_RESCREEN / RE_ENGAGEMENT
        [AssignedToUserId]  INT            NULL,
        [Notes]             NVARCHAR(2000) NULL,
        [Status]            VARCHAR(20)    NOT NULL
            CONSTRAINT [DF_CMS_FollowUps_Status] DEFAULT ('SCHEDULED'), -- SCHEDULED / COMPLETED / MISSED / CANCELLED
        [OutcomeNotes]      NVARCHAR(2000) NULL,
        [RowVersion]        ROWVERSION     NOT NULL,
        [IsActive]          BIT            NOT NULL CONSTRAINT [DF_CMS_FollowUps_Active] DEFAULT (1),
        [CreatedBy]         INT            NOT NULL,
        [CreatedAt]         DATETIME2      NOT NULL CONSTRAINT [DF_CMS_FollowUps_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [ModifiedBy]        INT            NULL,
        [ModifiedAt]        DATETIME2      NULL,
        [IpAddress]         VARCHAR(50)    NULL,
        CONSTRAINT [PK_CMS_FollowUps] PRIMARY KEY CLUSTERED ([FollowUpId]),
        CONSTRAINT [FK_CMS_FollowUps_Case]
            FOREIGN KEY ([CaseId]) REFERENCES [dbo].[CMS_Cases] ([CaseId])
    );
    CREATE INDEX [IX_CMS_FollowUps_Case] ON [dbo].[CMS_FollowUps] ([CaseId], [ScheduledDate]);
END
GO

/* ---- Lost-to-follow-up tracking (one row per case; history preserved) ---- */
IF OBJECT_ID(N'[dbo].[CMS_LostToFollowUps]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_LostToFollowUps] (
        [LtfuId]              INT            IDENTITY(1,1) NOT NULL,
        [CaseId]              INT            NOT NULL,
        [MissedCount]         INT            NOT NULL CONSTRAINT [DF_CMS_LostToFollowUps_Missed] DEFAULT (0),
        [LastContactDate]     DATETIME2      NULL,
        [LtfuDeclaredDate]    DATETIME2      NULL,
        [Status]              VARCHAR(20)    NOT NULL
            CONSTRAINT [DF_CMS_LostToFollowUps_Status] DEFAULT ('AT_RISK'), -- AT_RISK / LTFU / RE_ENGAGED
        [ReEngagementNotes]   NVARCHAR(2000) NULL,
        [RowVersion]          ROWVERSION     NOT NULL,
        [IsActive]            BIT            NOT NULL CONSTRAINT [DF_CMS_LostToFollowUps_Active] DEFAULT (1),
        [CreatedBy]           INT            NOT NULL,
        [CreatedAt]           DATETIME2      NOT NULL CONSTRAINT [DF_CMS_LostToFollowUps_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [ModifiedBy]          INT            NULL,
        [ModifiedAt]          DATETIME2      NULL,
        [IpAddress]           VARCHAR(50)    NULL,
        CONSTRAINT [PK_CMS_LostToFollowUps] PRIMARY KEY CLUSTERED ([LtfuId]),
        CONSTRAINT [UQ_CMS_LostToFollowUps_Case] UNIQUE NONCLUSTERED ([CaseId]),
        CONSTRAINT [FK_CMS_LostToFollowUps_Case]
            FOREIGN KEY ([CaseId]) REFERENCES [dbo].[CMS_Cases] ([CaseId])
    );
END
GO

/* ---- Case closure requests (two-step: request -> supervisor approval).
        Reopened cases may carry more than one closure row; only one
        PENDING request per case is allowed at a time. ---- */
IF OBJECT_ID(N'[dbo].[CMS_CaseClosures]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_CaseClosures] (
        [ClosureId]         INT            IDENTITY(1,1) NOT NULL,
        [CaseId]            INT            NOT NULL,
        [ClosureReason]     VARCHAR(40)    NOT NULL, -- TREATMENT_COMPLETE / SYMPTOM_REMISSION / LTFU / NO_CONSENT / REFERRAL_COMPLETE / OTHER
        [SymptomRemission]  BIT            NOT NULL CONSTRAINT [DF_CMS_CaseClosures_Remission] DEFAULT (0),
        [ClosureSummary]    NVARCHAR(MAX)  NULL,
        [ApprovalStatus]    VARCHAR(20)    NOT NULL
            CONSTRAINT [DF_CMS_CaseClosures_Approval] DEFAULT ('PENDING'), -- PENDING / APPROVED / REJECTED
        [RequestedByUserId] INT            NOT NULL,
        [RequestedAt]       DATETIME2      NOT NULL CONSTRAINT [DF_CMS_CaseClosures_RequestedAt] DEFAULT (SYSUTCDATETIME()),
        [ApprovedByUserId]  INT            NULL,
        [ApprovedAt]        DATETIME2      NULL,
        [RejectionReason]   NVARCHAR(1000) NULL,
        [RowVersion]        ROWVERSION     NOT NULL,
        [IsActive]          BIT            NOT NULL CONSTRAINT [DF_CMS_CaseClosures_Active] DEFAULT (1),
        [CreatedBy]         INT            NOT NULL,
        [CreatedAt]         DATETIME2      NOT NULL CONSTRAINT [DF_CMS_CaseClosures_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [ModifiedBy]        INT            NULL,
        [ModifiedAt]        DATETIME2      NULL,
        [IpAddress]         VARCHAR(50)    NULL,
        CONSTRAINT [PK_CMS_CaseClosures] PRIMARY KEY CLUSTERED ([ClosureId]),
        CONSTRAINT [FK_CMS_CaseClosures_Case]
            FOREIGN KEY ([CaseId]) REFERENCES [dbo].[CMS_Cases] ([CaseId])
    );
    CREATE UNIQUE INDEX [UQ_CMS_CaseClosures_PendingCase]
        ON [dbo].[CMS_CaseClosures] ([CaseId])
        WHERE [ApprovalStatus] = 'PENDING' AND [IsActive] = 1;
END
GO

/* ---- Supervision logs (S37 ongoing clinical and case supervision) ---- */
IF OBJECT_ID(N'[dbo].[CMS_SupervisionLogs]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_SupervisionLogs] (
        [SupervisionLogId]  INT            IDENTITY(1,1) NOT NULL,
        [CaseId]            INT            NOT NULL,
        [SupervisorUserId]  INT            NOT NULL,
        [ReviewDate]        DATETIME2      NOT NULL,
        [Findings]          NVARCHAR(MAX)  NOT NULL,
        [ActionItems]       NVARCHAR(MAX)  NULL,
        [Rating]            VARCHAR(30)    NULL, -- SATISFACTORY / NEEDS_IMPROVEMENT / UNSATISFACTORY
        [RowVersion]        ROWVERSION     NOT NULL,
        [IsActive]          BIT            NOT NULL CONSTRAINT [DF_CMS_SupervisionLogs_Active] DEFAULT (1),
        [CreatedBy]         INT            NOT NULL,
        [CreatedAt]         DATETIME2      NOT NULL CONSTRAINT [DF_CMS_SupervisionLogs_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [ModifiedBy]        INT            NULL,
        [ModifiedAt]        DATETIME2      NULL,
        [IpAddress]         VARCHAR(50)    NULL,
        CONSTRAINT [PK_CMS_SupervisionLogs] PRIMARY KEY CLUSTERED ([SupervisionLogId]),
        CONSTRAINT [FK_CMS_SupervisionLogs_Case]
            FOREIGN KEY ([CaseId]) REFERENCES [dbo].[CMS_Cases] ([CaseId])
    );
    CREATE INDEX [IX_CMS_SupervisionLogs_Case] ON [dbo].[CMS_SupervisionLogs] ([CaseId], [ReviewDate]);
END
GO

/* ---- System settings (risk-based follow-up frequencies, LTFU threshold).
        IsClientSourced = 0 means the value is provisional and must be
        confirmed with the client before go-live. ---- */
IF OBJECT_ID(N'[dbo].[CMS_SystemSettings]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_SystemSettings] (
        [SettingKey]     VARCHAR(100)   NOT NULL,
        [SettingValue]   NVARCHAR(500)  NOT NULL,
        [Description]    NVARCHAR(500)  NULL,
        [IsClientSourced] BIT           NOT NULL CONSTRAINT [DF_CMS_SystemSettings_Client] DEFAULT (0),
        [UpdatedBy]      INT            NULL,
        [UpdatedAt]      DATETIME2      NOT NULL CONSTRAINT [DF_CMS_SystemSettings_UpdatedAt] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_CMS_SystemSettings] PRIMARY KEY CLUSTERED ([SettingKey])
    );
END
GO
