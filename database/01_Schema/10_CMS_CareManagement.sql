/* ============================================================
   AKA-CMS — Sprint 5 schema (10)
   Module 3: Case Management, Assignment & Referral.

   Tables (all CMS_-prefixed; existing CO-HIS tables untouched):
     CMS_RiskRoutingRules   — risk category -> SLA + referral targets
                               + care-plan steps (from workflow sheet
                               S18-S23, S25-S26)
     CMS_ActionCarePlans     — per-case care plan with structured steps
     CMS_CaseAssignmentQueue — assignment queue with SLA due dates
     CMS_Referrals           — referrals; REJECTED creates a NEW row
                               (old row kept, linked via ParentReferralId)
     CMS_CaseComments        — append-only case notes/alerts

   Safe to re-run (guarded by OBJECT_ID / sys.sequences).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- CMS_RiskRoutingRules ---- */
IF OBJECT_ID(N'[dbo].[CMS_RiskRoutingRules]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_RiskRoutingRules](
        [RiskCategory]            VARCHAR(20)  NOT NULL, -- HIGH / MODERATE / LOW
        [DisplayName]             NVARCHAR(60) NOT NULL,
        [SlaHours]                INT          NOT NULL, -- response SLA in hours
        [ReferralTargets]         NVARCHAR(200) NOT NULL, -- CSV: PSYCHOLOGIST,PSYCHIATRIST,...
        [RequiresSupervisorAlert] BIT          NOT NULL CONSTRAINT [DF_CMS_RiskRoutingRules_SupAlert] DEFAULT(0),
        [CarePlanStepsJson]       NVARCHAR(MAX) NOT NULL, -- structured S-steps
        [RowVersion]              ROWVERSION   NOT NULL,
        [IsActive]                BIT          NOT NULL CONSTRAINT [DF_CMS_RiskRoutingRules_Active] DEFAULT(1),
        CONSTRAINT [PK_CMS_RiskRoutingRules] PRIMARY KEY ([RiskCategory])
    );
END
GO

/* ---- CMS_ActionCarePlans ---- */
IF OBJECT_ID(N'[dbo].[CMS_ActionCarePlans]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_ActionCarePlans](
        [ActionCarePlanId] INT            IDENTITY(1,1) NOT NULL,
        [CaseId]           INT            NOT NULL,
        [RiskCategory]     VARCHAR(20)    NOT NULL,
        [Title]            NVARCHAR(200)  NOT NULL,
        [StepsJson]        NVARCHAR(MAX)  NOT NULL, -- [{stepCode,title,status}]
        [Status]           VARCHAR(20)    NOT NULL CONSTRAINT [DF_CMS_ActionCarePlans_Status] DEFAULT('ACTIVE'),
        [CreatedBy]        INT            NOT NULL,
        [CreatedAt]        DATETIME2      NOT NULL CONSTRAINT [DF_CMS_ActionCarePlans_CreatedAt] DEFAULT(SYSUTCDATETIME()),
        [IpAddress]        VARCHAR(45)    NULL,
        [RowVersion]       ROWVERSION     NOT NULL,
        [IsActive]         BIT            NOT NULL CONSTRAINT [DF_CMS_ActionCarePlans_Active] DEFAULT(1),
        CONSTRAINT [PK_CMS_ActionCarePlans] PRIMARY KEY ([ActionCarePlanId]),
        CONSTRAINT [FK_CMS_ActionCarePlans_Case] FOREIGN KEY ([CaseId])
            REFERENCES [dbo].[CMS_Cases]([CaseId])
    );
    CREATE INDEX [IX_CMS_ActionCarePlans_CaseId] ON [dbo].[CMS_ActionCarePlans]([CaseId]);
END
GO

/* ---- CMS_CaseAssignmentQueue ---- */
IF OBJECT_ID(N'[dbo].[CMS_CaseAssignmentQueue]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_CaseAssignmentQueue](
        [QueueId]         INT          IDENTITY(1,1) NOT NULL,
        [CaseId]          INT          NOT NULL,
        [RiskCategory]    VARCHAR(20)  NOT NULL,
        [SlaDueAt]        DATETIME2   NOT NULL,
        [AssignedToUserId] INT         NULL,
        [Status]          VARCHAR(20)  NOT NULL CONSTRAINT [DF_CMS_AssignmentQueue_Status] DEFAULT('PENDING'),
        [EnqueuedBy]      INT          NOT NULL,
        [EnqueuedAt]      DATETIME2    NOT NULL CONSTRAINT [DF_CMS_AssignmentQueue_EnqueuedAt] DEFAULT(SYSUTCDATETIME()),
        [AssignedAt]      DATETIME2   NULL,
        [IpAddress]       VARCHAR(45)  NULL,
        [RowVersion]      ROWVERSION   NOT NULL,
        [IsActive]        BIT          NOT NULL CONSTRAINT [DF_CMS_AssignmentQueue_Active] DEFAULT(1),
        CONSTRAINT [PK_CMS_CaseAssignmentQueue] PRIMARY KEY ([QueueId]),
        CONSTRAINT [FK_CMS_AssignmentQueue_Case] FOREIGN KEY ([CaseId])
            REFERENCES [dbo].[CMS_Cases]([CaseId]),
        CONSTRAINT [FK_CMS_AssignmentQueue_User] FOREIGN KEY ([AssignedToUserId])
            REFERENCES [dbo].[USERS]([USERID])
    );
    CREATE INDEX [IX_CMS_AssignmentQueue_Status] ON [dbo].[CMS_CaseAssignmentQueue]([Status]) WHERE [IsActive] = 1;
END
GO

/* ---- CMS_ReferralNumberSeq ---- */
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE [name] = N'CMS_ReferralNumberSeq')
BEGIN
    CREATE SEQUENCE [dbo].[CMS_ReferralNumberSeq] AS INT START WITH 1 INCREMENT BY 1;
END
GO

/* ---- CMS_Referrals ---- */
IF OBJECT_ID(N'[dbo].[CMS_Referrals]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_Referrals](
        [ReferralId]       INT            IDENTITY(1,1) NOT NULL,
        [ReferralNumber]   VARCHAR(30)    NOT NULL,
        [CaseId]           INT            NOT NULL,
        [ReferredTo]       VARCHAR(40)    NOT NULL, -- PSYCHOLOGIST / PSYCHIATRIST / PSYCHOSOCIAL / EMERGENCY_SERVICES
        [Status]           VARCHAR(20)    NOT NULL CONSTRAINT [DF_CMS_Referrals_Status] DEFAULT('PENDING'),
        [RejectionReason]  NVARCHAR(500)  NULL,
        [ParentReferralId] INT            NULL, -- set on re-route rows
        [SlaDueAt]         DATETIME2      NOT NULL,
        [Notes]            NVARCHAR(500)  NULL,
        [CreatedBy]        INT            NOT NULL,
        [CreatedAt]        DATETIME2      NOT NULL CONSTRAINT [DF_CMS_Referrals_CreatedAt] DEFAULT(SYSUTCDATETIME()),
        [IpAddress]        VARCHAR(45)    NULL,
        [RowVersion]       ROWVERSION     NOT NULL,
        [IsActive]         BIT            NOT NULL CONSTRAINT [DF_CMS_Referrals_Active] DEFAULT(1),
        CONSTRAINT [PK_CMS_Referrals] PRIMARY KEY ([ReferralId]),
        CONSTRAINT [UQ_CMS_Referrals_Number] UNIQUE ([ReferralNumber]),
        CONSTRAINT [FK_CMS_Referrals_Case] FOREIGN KEY ([CaseId])
            REFERENCES [dbo].[CMS_Cases]([CaseId]),
        CONSTRAINT [FK_CMS_Referrals_Parent] FOREIGN KEY ([ParentReferralId])
            REFERENCES [dbo].[CMS_Referrals]([ReferralId])
    );
    CREATE INDEX [IX_CMS_Referrals_CaseId] ON [dbo].[CMS_Referrals]([CaseId]);
END
GO

/* ---- CMS_CaseComments (append-only) ---- */
IF OBJECT_ID(N'[dbo].[CMS_CaseComments]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_CaseComments](
        [CaseCommentId] INT           IDENTITY(1,1) NOT NULL,
        [CaseId]        INT           NOT NULL,
        [CommentType]   VARCHAR(20)   NOT NULL CONSTRAINT [DF_CMS_CaseComments_Type] DEFAULT('NOTE'),
        [Comment]       NVARCHAR(2000) NOT NULL,
        [CreatedBy]     INT           NOT NULL,
        [CreatedAt]     DATETIME2     NOT NULL CONSTRAINT [DF_CMS_CaseComments_CreatedAt] DEFAULT(SYSUTCDATETIME()),
        [IpAddress]     VARCHAR(45)   NULL,
        [IsActive]      BIT           NOT NULL CONSTRAINT [DF_CMS_CaseComments_Active] DEFAULT(1),
        CONSTRAINT [PK_CMS_CaseComments] PRIMARY KEY ([CaseCommentId]),
        CONSTRAINT [FK_CMS_CaseComments_Case] FOREIGN KEY ([CaseId])
            REFERENCES [dbo].[CMS_Cases]([CaseId])
    );
    CREATE INDEX [IX_CMS_CaseComments_CaseId] ON [dbo].[CMS_CaseComments]([CaseId]);
END
GO
