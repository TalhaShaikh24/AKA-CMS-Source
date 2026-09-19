/* ============================================================
   AKA-CMS — Sprint 6: Modules 4 & 5 (Psychological +
   Pharmacological Treatment) — tables.

   Authoritative basis:
   - IMHP-CMS_API_Development_Handoff.md §4 Sprint 6: modules
     TreatmentPlans, PsychologicalSessions, MedicationDictionary,
     MedicationPrescriptions. sp_MedicationPrescription_Create must
     validate against MedicationDictionary — no free-text drug names.
   - Wireframing logic (Proposed_Wireframing_Logic...pdf) Figure 7/8:
     psychological pathway = assessment, structured treatment
     planning, session documentation, outcome monitoring;
     pharmacological pathway = psychiatric evaluation, diagnosis,
     medication planning, adherence monitoring, structured follow-up
     (standard mhGAP-IG guidelines). S28-S30: both tracks run in
     parallel against the same case.
   - AKU_-_Technical_Proposal_V1.pdf: Module 4 "Psychological
     treatment", Module 5 "Pharmacological Treatment" (psychiatric
     evaluation records, diagnosis management, medication tracking,
     adherence monitoring, follow-up scheduling).

   Neither client doc names a medication formulary or a modality
   list, so CMS_MedicationDictionary is seeded (file 17) from the
   WHO mhGAP-IG essential psychotropic medicines and
   CMS_PsychModalityTypes from standard mhGAP-IG psychological
   interventions — every seeded row carries
   ClinicalConfirmationPending/IsClientSourced = 0 and a note that
   clinical sign-off from the client is required before go-live.

   Existing CO-HIS tables (incl. HIS PRESCRIPTIONS / TRANS_*
   pharmacy tables) are untouched; the CMS tracks reference only
   CMS_-prefixed objects plus CMS_Cases. Safe to re-run
   (guarded by OBJECT_ID / sys.sequences).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- CMS_TreatmentPlans: one row per track (PSYCH/PHARM) per case.
   Both S28 tracks are created independently against the same case;
   progress is tracked together via sp_CMS_TreatmentPlan_GetByCase. */
IF OBJECT_ID(N'[dbo].[CMS_TreatmentPlans]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_TreatmentPlans] (
        [PlanId]               INT            IDENTITY(1,1) NOT NULL,
        [CaseId]               INT            NOT NULL,
        [PlanTrack]            VARCHAR(10)    NOT NULL,  -- PSYCH | PHARM
        [Title]                NVARCHAR(200)  NOT NULL,
        [Goals]                NVARCHAR(2000) NULL,
        [PlannedInterventions] NVARCHAR(2000) NULL,
        [StartDate]            DATE           NOT NULL,
        [PlannedEndDate]       DATE           NULL,
        [Status]               VARCHAR(20)    NOT NULL
            CONSTRAINT [DF_CMS_TreatmentPlans_Status] DEFAULT ('Active'),
        [RowVersion]           ROWVERSION     NOT NULL,
        [IsActive]             BIT            NOT NULL
            CONSTRAINT [DF_CMS_TreatmentPlans_IsActive] DEFAULT (1),
        [CreatedAt]            DATETIME2(0)   NOT NULL
            CONSTRAINT [DF_CMS_TreatmentPlans_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [CreatedBy]            INT            NULL,  -- operator user id; no FK to existing USERS (CMS never alters CO-HIS)
        [IpAddress]            VARCHAR(50)    NULL,
        CONSTRAINT [PK_CMS_TreatmentPlans] PRIMARY KEY CLUSTERED ([PlanId]),
        CONSTRAINT [CK_CMS_TreatmentPlans_Track] CHECK ([PlanTrack] IN ('PSYCH', 'PHARM')),
        CONSTRAINT [CK_CMS_TreatmentPlans_Status] CHECK ([Status] IN ('Active', 'Completed', 'Discontinued')),
        CONSTRAINT [FK_CMS_TreatmentPlans_Case] FOREIGN KEY ([CaseId])
            REFERENCES [dbo].[CMS_Cases] ([CaseId])
    );

    /* One active plan per track per case (S28 parallel tracks). */
    CREATE UNIQUE NONCLUSTERED INDEX [UQ_CMS_TreatmentPlans_ActiveTrack]
        ON [dbo].[CMS_TreatmentPlans] ([CaseId], [PlanTrack])
        WHERE [Status] = 'Active' AND [IsActive] = 1;
END
GO

/* ---- CMS_PsychModalityTypes: psychological intervention modalities.
   Catalog only; seeds live in 17_CMS_TreatmentSeed.sql. */
IF OBJECT_ID(N'[dbo].[CMS_PsychModalityTypes]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_PsychModalityTypes] (
        [ModalityCode]   VARCHAR(20)    NOT NULL,
        [DisplayName]    NVARCHAR(100)  NOT NULL,
        [Description]    NVARCHAR(500)  NULL,
        [IsClientSourced] BIT           NOT NULL
            CONSTRAINT [DF_CMS_PsychModalityTypes_ClientSourced] DEFAULT (0),
        [SortOrder]      INT            NOT NULL
            CONSTRAINT [DF_CMS_PsychModalityTypes_SortOrder] DEFAULT (0),
        [IsActive]       BIT            NOT NULL
            CONSTRAINT [DF_CMS_PsychModalityTypes_IsActive] DEFAULT (1),
        CONSTRAINT [PK_CMS_PsychModalityTypes] PRIMARY KEY CLUSTERED ([ModalityCode])
    );
END
GO

/* ---- CMS_PsychologicalSessions: session documentation per plan
   (Figure 7: assessment, structured treatment planning, session
   documentation, outcome monitoring). A session always belongs to an
   active treatment plan — never to a bare case. */
IF OBJECT_ID(N'[dbo].[CMS_PsychologicalSessions]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_PsychologicalSessions] (
        [SessionId]       INT            IDENTITY(1,1) NOT NULL,
        [PlanId]          INT            NOT NULL,
        [CaseId]          INT            NOT NULL,
        [TherapistUserId] INT            NULL,  -- no FK to existing USERS (CMS never alters CO-HIS)
        [SessionDate]     DATETIME2(0)   NOT NULL,
        [ModalityCode]    VARCHAR(20)    NOT NULL,
        [DurationMinutes] INT            NULL,
        [SessionNotes]    NVARCHAR(2000) NULL,
        [OutcomeNotes]    NVARCHAR(2000) NULL,
        [NextSessionDate] DATE           NULL,
        [RowVersion]      ROWVERSION     NOT NULL,
        [IsActive]        BIT            NOT NULL
            CONSTRAINT [DF_CMS_PsychologicalSessions_IsActive] DEFAULT (1),
        [CreatedAt]       DATETIME2(0)   NOT NULL
            CONSTRAINT [DF_CMS_PsychologicalSessions_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [CreatedBy]       INT            NULL,
        [IpAddress]       VARCHAR(50)    NULL,
        CONSTRAINT [PK_CMS_PsychologicalSessions] PRIMARY KEY CLUSTERED ([SessionId]),
        CONSTRAINT [FK_CMS_PsychologicalSessions_Plan] FOREIGN KEY ([PlanId])
            REFERENCES [dbo].[CMS_TreatmentPlans] ([PlanId]),
        CONSTRAINT [FK_CMS_PsychologicalSessions_Case] FOREIGN KEY ([CaseId])
            REFERENCES [dbo].[CMS_Cases] ([CaseId]),
        CONSTRAINT [FK_CMS_PsychologicalSessions_Modality] FOREIGN KEY ([ModalityCode])
            REFERENCES [dbo].[CMS_PsychModalityTypes] ([ModalityCode])
    );

    CREATE NONCLUSTERED INDEX [IX_CMS_PsychologicalSessions_Case]
        ON [dbo].[CMS_PsychologicalSessions] ([CaseId], [SessionDate]);
END
GO

/* ---- Sequence for prescription numbers (RX-YYYY-######).
   Mirrors the CMS_CaseNumberSeq / CMS_ReferralNumberSeq pattern. */
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE [name] = N'CMS_PrescriptionNumberSeq')
BEGIN
    CREATE SEQUENCE [dbo].[CMS_PrescriptionNumberSeq] AS INT START WITH 1 INCREMENT BY 1;
END
GO

/* ---- CMS_MedicationDictionary: controlled formulary.
   sp_MedicationPrescription_Create validates against this table —
   no free-text drug names anywhere in the API. Seeds in file 17. */
IF OBJECT_ID(N'[dbo].[CMS_MedicationDictionary]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_MedicationDictionary] (
        [MedicationId]              INT            IDENTITY(1,1) NOT NULL,
        [MedicationCode]            VARCHAR(20)    NOT NULL,
        [GenericName]               NVARCHAR(200)  NOT NULL,
        [Strength]                  NVARCHAR(50)   NULL,
        [DosageForm]                NVARCHAR(50)   NULL,
        [IsActive]                  BIT            NOT NULL
            CONSTRAINT [DF_CMS_MedicationDictionary_IsActive] DEFAULT (1),
        [ClinicalConfirmationPending] BIT         NOT NULL
            CONSTRAINT [DF_CMS_MedicationDictionary_ConfirmPending] DEFAULT (1),
        [SortOrder]                 INT            NOT NULL
            CONSTRAINT [DF_CMS_MedicationDictionary_SortOrder] DEFAULT (0),
        CONSTRAINT [PK_CMS_MedicationDictionary] PRIMARY KEY CLUSTERED ([MedicationId]),
        CONSTRAINT [UQ_CMS_MedicationDictionary_Code] UNIQUE ([MedicationCode])
    );
END
GO

/* ---- CMS_MedicationPrescriptions: psychiatric medication planning.
   Linked to the PHARM-track plan when one exists. Cancellation is a
   soft status change (audit trail preserved, never deleted). */
IF OBJECT_ID(N'[dbo].[CMS_MedicationPrescriptions]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_MedicationPrescriptions] (
        [PrescriptionId]    INT            IDENTITY(1,1) NOT NULL,
        [RxNumber]          VARCHAR(20)    NOT NULL,
        [CaseId]            INT            NOT NULL,
        [PlanId]            INT            NULL,
        [MedicationId]      INT            NOT NULL,
        [PrescribedByUserId] INT           NULL,  -- no FK to existing USERS (CMS never alters CO-HIS)
        [DoseText]          NVARCHAR(100)  NOT NULL,
        [Frequency]         NVARCHAR(100)  NOT NULL,
        [DurationDays]      INT            NOT NULL,
        [Instructions]      NVARCHAR(500)  NULL,
        [DiagnosisText]     NVARCHAR(500)  NULL,  -- psychiatric evaluation / diagnosis note (Figure 8)
        [Status]            VARCHAR(20)    NOT NULL
            CONSTRAINT [DF_CMS_MedicationPrescriptions_Status] DEFAULT ('Active'),
        [RowVersion]        ROWVERSION     NOT NULL,
        [IsActive]          BIT            NOT NULL
            CONSTRAINT [DF_CMS_MedicationPrescriptions_IsActive] DEFAULT (1),
        [CreatedAt]         DATETIME2(0)   NOT NULL
            CONSTRAINT [DF_CMS_MedicationPrescriptions_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [CreatedBy]         INT            NULL,
        [IpAddress]         VARCHAR(50)    NULL,
        CONSTRAINT [PK_CMS_MedicationPrescriptions] PRIMARY KEY CLUSTERED ([PrescriptionId]),
        CONSTRAINT [UQ_CMS_MedicationPrescriptions_RxNumber] UNIQUE ([RxNumber]),
        CONSTRAINT [CK_CMS_MedicationPrescriptions_Status] CHECK ([Status] IN ('Active', 'Cancelled', 'Completed')),
        CONSTRAINT [FK_CMS_MedicationPrescriptions_Case] FOREIGN KEY ([CaseId])
            REFERENCES [dbo].[CMS_Cases] ([CaseId]),
        CONSTRAINT [FK_CMS_MedicationPrescriptions_Plan] FOREIGN KEY ([PlanId])
            REFERENCES [dbo].[CMS_TreatmentPlans] ([PlanId]),
        CONSTRAINT [FK_CMS_MedicationPrescriptions_Medication] FOREIGN KEY ([MedicationId])
            REFERENCES [dbo].[CMS_MedicationDictionary] ([MedicationId])
    );

    CREATE NONCLUSTERED INDEX [IX_CMS_MedicationPrescriptions_Case]
        ON [dbo].[CMS_MedicationPrescriptions] ([CaseId], [Status]);
END
GO

/* ---- CMS_MedicationDispensing: dispensing + adherence monitoring
   (Technical Proposal Module 5: "Medication tracking", "Adherence
   monitoring"). One row per dispensing event against a prescription. */
IF OBJECT_ID(N'[dbo].[CMS_MedicationDispensing]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_MedicationDispensing] (
        [DispenseId]       INT            IDENTITY(1,1) NOT NULL,
        [PrescriptionId]   INT            NOT NULL,
        [DispensedDate]    DATETIME2(0)   NOT NULL,
        [Quantity]         DECIMAL(10,2)  NOT NULL,
        [DispensedByUserId] INT           NULL,  -- no FK to existing USERS (CMS never alters CO-HIS)
        [AdherenceNotes]   NVARCHAR(1000) NULL,
        [RowVersion]       ROWVERSION     NOT NULL,
        [IsActive]         BIT            NOT NULL
            CONSTRAINT [DF_CMS_MedicationDispensing_IsActive] DEFAULT (1),
        [CreatedAt]        DATETIME2(0)   NOT NULL
            CONSTRAINT [DF_CMS_MedicationDispensing_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [CreatedBy]        INT            NULL,
        [IpAddress]        VARCHAR(50)    NULL,
        CONSTRAINT [PK_CMS_MedicationDispensing] PRIMARY KEY CLUSTERED ([DispenseId]),
        CONSTRAINT [FK_CMS_MedicationDispensing_Prescription] FOREIGN KEY ([PrescriptionId])
            REFERENCES [dbo].[CMS_MedicationPrescriptions] ([PrescriptionId])
    );

    CREATE NONCLUSTERED INDEX [IX_CMS_MedicationDispensing_Prescription]
        ON [dbo].[CMS_MedicationDispensing] ([PrescriptionId], [DispensedDate]);
END
GO
