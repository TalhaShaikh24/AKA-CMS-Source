/* ============================================================
   AKA-CMS — Sprint 4 schema (12)
   Module 2: Helpline & Crisis Management.

   Tables (all CMS_-prefixed; existing CO-HIS tables untouched):
     CMS_CrisisTypes    — crisis type catalog (seeded from the
                          Technical Proposal v1, Phase C "Crisis
                          Detection" trigger conditions).
     CMS_HelplineCalls  — inbound helpline call log; crisis
                          indicators stored as structured JSON,
                          resolved type codes as CSV.
     CMS_CrisisEvents   — acute crisis episodes linked to a case;
                          drives the S7a-S7i emergency path.
     CMS_SafetyPlans    — safety plan created during crisis
                          management (Proposal Phase D).
     CMS_Notifications  — MINIMAL alert table, created early only
                          to carry the S7a "Immediate Alert".
                          Sprint 8 will extend this with
                          templates / delivery channels.

   Safe to re-run (guarded by OBJECT_ID).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- CMS_CrisisTypes ---- */
IF OBJECT_ID(N'[dbo].[CMS_CrisisTypes]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_CrisisTypes](
        [CrisisTypeCode]  VARCHAR(10)   NOT NULL, -- SUI / SHM / PSY / PAN / SUB / OTH
        [DisplayName]     NVARCHAR(100) NOT NULL,
        [DefaultSeverity] VARCHAR(10)   NOT NULL, -- CRITICAL / HIGH
        [Description]     NVARCHAR(500) NULL,
        [SortOrder]       INT           NOT NULL CONSTRAINT [DF_CMS_CrisisTypes_Sort] DEFAULT(100),
        [IsActive]        BIT           NOT NULL CONSTRAINT [DF_CMS_CrisisTypes_Active] DEFAULT(1),
        CONSTRAINT [PK_CMS_CrisisTypes] PRIMARY KEY ([CrisisTypeCode])
    );
END
GO

/* ---- CMS_Notifications (minimal; Sprint 8 extends) ---- */
IF OBJECT_ID(N'[dbo].[CMS_Notifications]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_Notifications](
        [NotificationId]  INT            IDENTITY(1,1) NOT NULL,
        [RecipientRole]   VARCHAR(60)    NULL, -- e.g. SUPERVISOR; NULL = broadcast
        [RecipientUserId] INT            NULL, -- direct user target (optional)
        [Title]           NVARCHAR(200)  NOT NULL,
        [Body]            NVARCHAR(MAX)  NOT NULL,
        [RelatedCaseId]   INT            NULL,
        [RelatedEntity]   VARCHAR(60)    NULL, -- e.g. CRISIS_EVENT / HELPLINE_CALL
        [RelatedEntityId] INT            NULL,
        [IsRead]          BIT            NOT NULL CONSTRAINT [DF_CMS_Notifications_IsRead] DEFAULT(0),
        [CreatedAt]       DATETIME2      NOT NULL CONSTRAINT [DF_CMS_Notifications_CreatedAt] DEFAULT(SYSUTCDATETIME()),
        [IsActive]        BIT            NOT NULL CONSTRAINT [DF_CMS_Notifications_Active] DEFAULT(1),
        CONSTRAINT [PK_CMS_Notifications] PRIMARY KEY ([NotificationId]),
        CONSTRAINT [FK_CMS_Notifications_Case] FOREIGN KEY ([RelatedCaseId])
            REFERENCES [dbo].[CMS_Cases]([CaseId])
    );
    CREATE INDEX [IX_CMS_Notifications_Case] ON [dbo].[CMS_Notifications]([RelatedCaseId]);
END
GO

/* ---- CMS_HelplineCalls ---- */
IF OBJECT_ID(N'[dbo].[CMS_HelplineCalls]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_HelplineCalls](
        [HelplineCallId]        INT            IDENTITY(1,1) NOT NULL,
        [CallerName]            NVARCHAR(200)  NULL,
        [CallerPhone]           VARCHAR(30)    NULL,
        [CaseId]                INT            NULL, -- NULL when caller not yet identified
        [CrisisIndicatorsJson]  NVARCHAR(MAX)  NULL, -- structured indicator flags
        [CrisisTypeCodes]       VARCHAR(200)   NULL, -- resolved codes CSV (SUI,SHM,...)
        [CrisisSeverity]        VARCHAR(10)    NULL, -- CRITICAL / HIGH
        [CallNotes]             NVARCHAR(MAX)  NULL,
        [HandledBy]             INT            NOT NULL,
        [CallStartedAt]         DATETIME2      NOT NULL CONSTRAINT [DF_CMS_HelplineCalls_Started] DEFAULT(SYSUTCDATETIME()),
        [CreatedAt]             DATETIME2      NOT NULL CONSTRAINT [DF_CMS_HelplineCalls_CreatedAt] DEFAULT(SYSUTCDATETIME()),
        [IpAddress]             VARCHAR(45)    NULL,
        [RowVersion]            ROWVERSION     NOT NULL,
        [IsActive]              BIT            NOT NULL CONSTRAINT [DF_CMS_HelplineCalls_Active] DEFAULT(1),
        CONSTRAINT [PK_CMS_HelplineCalls] PRIMARY KEY ([HelplineCallId]),
        CONSTRAINT [FK_CMS_HelplineCalls_Case] FOREIGN KEY ([CaseId])
            REFERENCES [dbo].[CMS_Cases]([CaseId])
    );
    CREATE INDEX [IX_CMS_HelplineCalls_Case] ON [dbo].[CMS_HelplineCalls]([CaseId]);
END
GO

/* ---- CMS_CrisisEvents ---- */
IF OBJECT_ID(N'[dbo].[CMS_CrisisEvents]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_CrisisEvents](
        [CrisisEventId]   INT            IDENTITY(1,1) NOT NULL,
        [CaseId]          INT            NOT NULL,
        [CrisisTypeCode]  VARCHAR(10)    NOT NULL,
        [Severity]        VARCHAR(10)    NOT NULL, -- CRITICAL / HIGH / MODERATE
        [TriggerSource]   VARCHAR(30)    NOT NULL, -- HELPLINE_CALL / SCREENING_SEVERE / MANUAL
        [Status]          VARCHAR(20)    NOT NULL CONSTRAINT [DF_CMS_CrisisEvents_Status] DEFAULT('OPEN'),
        [Notes]           NVARCHAR(MAX)  NULL,
        [CreatedBy]       INT            NOT NULL,
        [CreatedAt]       DATETIME2      NOT NULL CONSTRAINT [DF_CMS_CrisisEvents_CreatedAt] DEFAULT(SYSUTCDATETIME()),
        [UpdatedAt]       DATETIME2      NULL,
        [IpAddress]       VARCHAR(45)    NULL,
        [RowVersion]      ROWVERSION     NOT NULL,
        [IsActive]        BIT            NOT NULL CONSTRAINT [DF_CMS_CrisisEvents_Active] DEFAULT(1),
        CONSTRAINT [PK_CMS_CrisisEvents] PRIMARY KEY ([CrisisEventId]),
        CONSTRAINT [FK_CMS_CrisisEvents_Case] FOREIGN KEY ([CaseId])
            REFERENCES [dbo].[CMS_Cases]([CaseId]),
        CONSTRAINT [FK_CMS_CrisisEvents_Type] FOREIGN KEY ([CrisisTypeCode])
            REFERENCES [dbo].[CMS_CrisisTypes]([CrisisTypeCode])
    );
    CREATE INDEX [IX_CMS_CrisisEvents_Case] ON [dbo].[CMS_CrisisEvents]([CaseId]);
END
GO

/* ---- CMS_SafetyPlans ---- */
IF OBJECT_ID(N'[dbo].[CMS_SafetyPlans]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_SafetyPlans](
        [SafetyPlanId]         INT            IDENTITY(1,1) NOT NULL,
        [CaseId]               INT            NOT NULL,
        [WarningSigns]         NVARCHAR(MAX)  NOT NULL,
        [CopingStrategies]     NVARCHAR(MAX)  NOT NULL,
        [SupportContactsJson]  NVARCHAR(MAX)  NULL, -- [{name, phone, relationship}]
        [CreatedBy]            INT            NOT NULL,
        [CreatedAt]            DATETIME2      NOT NULL CONSTRAINT [DF_CMS_SafetyPlans_CreatedAt] DEFAULT(SYSUTCDATETIME()),
        [IpAddress]            VARCHAR(45)    NULL,
        [RowVersion]           ROWVERSION     NOT NULL,
        [IsActive]             BIT            NOT NULL CONSTRAINT [DF_CMS_SafetyPlans_Active] DEFAULT(1),
        CONSTRAINT [PK_CMS_SafetyPlans] PRIMARY KEY ([SafetyPlanId]),
        CONSTRAINT [FK_CMS_SafetyPlans_Case] FOREIGN KEY ([CaseId])
            REFERENCES [dbo].[CMS_Cases]([CaseId])
    );
    CREATE INDEX [IX_CMS_SafetyPlans_Case] ON [dbo].[CMS_SafetyPlans]([CaseId]);
END
GO
