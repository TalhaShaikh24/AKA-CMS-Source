/* ============================================================
   AKA-CMS — Module 1 remainder (14)
   Awareness sessions, session participants, case source mapping.

   Client-source basis (authoritative docs only):
   - AKU_-_Technical_Proposal_V1.pdf, "Phase 1: Awareness Session
     Recording": frontline worker logs in, creates an
     awareness/outreach session, the system generates a Session ID,
     and stores Date, Topic, Target group, Venue, Gender split and
     Screening data. Tables named there: AwarenessSessions,
     SessionParticipants.
   - Same proposal, "Phase 3: Case Intake & Registration":
     identified person escalated to a formal case; Case ID generated;
     the case is "Linked to session".
   - Wireframing logic (Proposed_Wireframing_Logic...pdf), S1 entry
     points: Community Entry / School Entry / Health Facility
     Entry / Helpline-Emergency Calls.
   - IMHP-CMS_API_Development_Handoff.md §4 Sprint 3 names the
     modules: AwarenessSessions, SessionParticipants, Cases,
     CaseSourceMapping. Its case-source examples are
     "AwarenessSession, WalkIn, Referral, Helpline, Screening etc."

   Source codes WalkIn and Referral come from the handoff examples
   ONLY — they are not named in any client doc. They are seeded
   with IsClientSourced = 0, pending client confirmation.

   Existing CO-HIS tables are untouched. Safe to re-run
   (guarded by OBJECT_ID / sys.sequences).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- CMS_CaseSourceTypes: case identification channel catalog ---- */
IF OBJECT_ID(N'[dbo].[CMS_CaseSourceTypes]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_CaseSourceTypes] (
        [SourceTypeCode]  VARCHAR(30)  NOT NULL,
        [DisplayName]     NVARCHAR(100) NOT NULL,
        [Description]     NVARCHAR(500) NULL,
        [IsClientSourced] BIT          NOT NULL CONSTRAINT [DF_CMS_CaseSourceTypes_ClientSourced] DEFAULT (1),
        [SortOrder]       INT          NOT NULL CONSTRAINT [DF_CMS_CaseSourceTypes_SortOrder] DEFAULT (0),
        [IsActive]        BIT          NOT NULL CONSTRAINT [DF_CMS_CaseSourceTypes_IsActive] DEFAULT (1),
        CONSTRAINT [PK_CMS_CaseSourceTypes] PRIMARY KEY CLUSTERED ([SourceTypeCode])
    );
END
GO

/* ---- Sequence for auto-generated session codes (SES-YYYY-######) ----
   Mirrors the CMS_CaseNumberSeq pattern used for case numbers. */
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE [name] = N'CMS_AwarenessSessionSeq')
BEGIN
    CREATE SEQUENCE [dbo].[CMS_AwarenessSessionSeq] AS INT START WITH 1 INCREMENT BY 1;
END
GO

/* ---- CMS_AwarenessSessions: community awareness/outreach sessions ---- */
IF OBJECT_ID(N'[dbo].[CMS_AwarenessSessions]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_AwarenessSessions] (
        [SessionId]      INT            IDENTITY(1,1) NOT NULL,
        [SessionCode]    VARCHAR(20)    NOT NULL,
        [Title]          NVARCHAR(200)  NOT NULL,
        [FacilityCode]   VARCHAR(20)    NULL,
        [SessionDate]    DATE           NOT NULL,
        [ConductedBy]    INT            NULL,     -- operator user id; no FK to existing USERS (CMS never alters CO-HIS)
        [Topic]          NVARCHAR(200)  NULL,
        [TargetGroup]    NVARCHAR(100)  NULL,    -- "Target group" per Technical Proposal Phase 1
        [Venue]          NVARCHAR(200)  NULL,
        [MaleCount]      INT            NOT NULL CONSTRAINT [DF_CMS_AwarenessSessions_MaleCount] DEFAULT (0),
        [FemaleCount]    INT            NOT NULL CONSTRAINT [DF_CMS_AwarenessSessions_FemaleCount] DEFAULT (0),
        [OtherCount]     INT            NOT NULL CONSTRAINT [DF_CMS_AwarenessSessions_OtherCount] DEFAULT (0),
        [Notes]          NVARCHAR(2000) NULL,
        [RowVersion]     ROWVERSION     NOT NULL,
        [IsActive]       BIT            NOT NULL CONSTRAINT [DF_CMS_AwarenessSessions_IsActive] DEFAULT (1),
        [CreatedAt]      DATETIME2(0)   NOT NULL CONSTRAINT [DF_CMS_AwarenessSessions_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [UpdatedAt]      DATETIME2(0)   NOT NULL CONSTRAINT [DF_CMS_AwarenessSessions_CreatedAt2] DEFAULT (SYSUTCDATETIME()),
        [CreatedBy]      INT            NULL,
        [IpAddress]      VARCHAR(50)    NULL,
        CONSTRAINT [PK_CMS_AwarenessSessions] PRIMARY KEY CLUSTERED ([SessionId]),
        CONSTRAINT [UQ_CMS_AwarenessSessions_SessionCode] UNIQUE ([SessionCode])
    );
END
GO

/* ---- CMS_SessionParticipants: attendance capture for a session ----
   Participants may be registered community members (CommunityMemberId)
   or walk-ins recorded by name (ParticipantName fallback). */
IF OBJECT_ID(N'[dbo].[CMS_SessionParticipants]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_SessionParticipants] (
        [ParticipantId]         INT            IDENTITY(1,1) NOT NULL,
        [SessionId]             INT            NOT NULL,
        [CommunityMemberId]     INT            NULL,
        [ParticipantName]       NVARCHAR(200)  NULL,
        [Attended]              BIT            NOT NULL CONSTRAINT [DF_CMS_SessionParticipants_Attended] DEFAULT (1),
        [ConsentedToScreening]  BIT            NOT NULL CONSTRAINT [DF_CMS_SessionParticipants_Consented] DEFAULT (0),
        [ScreeningId]           INT            NULL,   -- screening administered in-session (Phase 2: Case Identification)
        [RowVersion]            ROWVERSION     NOT NULL,
        [IsActive]              BIT            NOT NULL CONSTRAINT [DF_CMS_SessionParticipants_IsActive] DEFAULT (1),
        [CreatedAt]             DATETIME2(0)   NOT NULL CONSTRAINT [DF_CMS_SessionParticipants_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [CreatedBy]             INT            NULL,
        [IpAddress]             VARCHAR(50)    NULL,
        CONSTRAINT [PK_CMS_SessionParticipants] PRIMARY KEY CLUSTERED ([ParticipantId]),
        CONSTRAINT [FK_CMS_SessionParticipants_Session] FOREIGN KEY ([SessionId])
            REFERENCES [dbo].[CMS_AwarenessSessions] ([SessionId]),
        CONSTRAINT [FK_CMS_SessionParticipants_Member] FOREIGN KEY ([CommunityMemberId])
            REFERENCES [dbo].[CMS_CommunityMembers] ([MemberId]),
        CONSTRAINT [FK_CMS_SessionParticipants_Screening] FOREIGN KEY ([ScreeningId])
            REFERENCES [dbo].[CMS_Screenings] ([ScreeningId])
    );

    /* Idempotency: one row per session per registered member ... */
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [name] = N'UQ_CMS_SessionParticipants_Member'
                   AND [object_id] = OBJECT_ID(N'[dbo].[CMS_SessionParticipants]'))
        CREATE UNIQUE NONCLUSTERED INDEX [UQ_CMS_SessionParticipants_Member]
            ON [dbo].[CMS_SessionParticipants] ([SessionId], [CommunityMemberId])
            WHERE [CommunityMemberId] IS NOT NULL;

    /* ... and one row per session per walk-in name. */
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE [name] = N'UQ_CMS_SessionParticipants_WalkIn'
                   AND [object_id] = OBJECT_ID(N'[dbo].[CMS_SessionParticipants]'))
        CREATE UNIQUE NONCLUSTERED INDEX [UQ_CMS_SessionParticipants_WalkIn]
            ON [dbo].[CMS_SessionParticipants] ([SessionId], [ParticipantName])
            WHERE [ParticipantName] IS NOT NULL;
END
GO

/* ---- CMS_CaseSourceMapping: every case carries its identification source ----
   One row per case. SourceReferenceId is polymorphic: for source
   AwarenessSession it holds the SessionId; for Helpline the
   HelplineCallId; otherwise NULL. (No FK — a polymorphic reference
   cannot be constrained to one table.) */
IF OBJECT_ID(N'[dbo].[CMS_CaseSourceMapping]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_CaseSourceMapping] (
        [MappingId]         INT          IDENTITY(1,1) NOT NULL,
        [CaseId]            INT          NOT NULL,
        [SourceType]        VARCHAR(30)  NOT NULL,
        [SourceReferenceId] INT          NULL,
        [CreatedAt]         DATETIME2(0) NOT NULL CONSTRAINT [DF_CMS_CaseSourceMapping_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [CreatedBy]         INT          NULL,
        [IpAddress]         VARCHAR(50)  NULL,
        CONSTRAINT [PK_CMS_CaseSourceMapping] PRIMARY KEY CLUSTERED ([MappingId]),
        CONSTRAINT [UQ_CMS_CaseSourceMapping_Case] UNIQUE ([CaseId]),
        CONSTRAINT [FK_CMS_CaseSourceMapping_Case] FOREIGN KEY ([CaseId])
            REFERENCES [dbo].[CMS_Cases] ([CaseId]),
        CONSTRAINT [FK_CMS_CaseSourceMapping_SourceType] FOREIGN KEY ([SourceType])
            REFERENCES [dbo].[CMS_CaseSourceTypes] ([SourceTypeCode])
    );
END
GO
