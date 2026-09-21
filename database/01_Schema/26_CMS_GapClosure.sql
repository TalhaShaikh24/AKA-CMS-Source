/* ============================================================
   AKA-CMS — Gap-closure schema (26)
   Closes workflow gaps identified against the client workflow
   sheet (Cases tab, S1-S38):

   Gap 1 (DASS-21): CMS_Screenings gets SubscaleScoresJson to
     persist the per-subscale scores (Depression/Anxiety/Stress).
   Gap 3 (Engage Carers — S5b/S20-High/S19-Mod/S19-Low/S35):
     new CMS_Carers table — carers linked to a case, soft-deactivate
     only (no hard delete), one primary carer per case enforced by
     the stored procedures.
   Gap 4 (Supervisor review before assignment — S16):
     additive CMS_Cases.SupervisorReviewedAt / SupervisorReviewedBy
     columns; existing data untouched (NULL = not yet reviewed).
   Safe to re-run (guarded by OBJECT_ID / COL_LENGTH checks).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- Gap 1: subscale scores on screenings ---- */
IF COL_LENGTH(N'[dbo].[CMS_Screenings]', N'SubscaleScoresJson') IS NULL
BEGIN
    ALTER TABLE [dbo].[CMS_Screenings]
        ADD [SubscaleScoresJson] NVARCHAR(500) NULL;
END
GO

/* ---- Gap 4: supervisor review stamp on cases ---- */
IF COL_LENGTH(N'[dbo].[CMS_Cases]', N'SupervisorReviewedAt') IS NULL
BEGIN
    ALTER TABLE [dbo].[CMS_Cases]
        ADD [SupervisorReviewedAt] DATETIME2 NULL,
            [SupervisorReviewedBy] INT NULL;
END
GO

/* ---- Gap 3: carers ---- */
IF OBJECT_ID(N'[dbo].[CMS_Carers]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_Carers](
        [CarerId]      INT            IDENTITY(1,1) NOT NULL,
        [CaseId]       INT            NOT NULL,
        [FullName]     NVARCHAR(200)  NOT NULL,
        [Relationship] NVARCHAR(100)  NULL,
        [Phone]        VARCHAR(30)    NULL,
        [IsPrimary]    BIT            NOT NULL CONSTRAINT [DF_CMS_Carers_IsPrimary] DEFAULT (0),
        [IsActive]     BIT            NOT NULL CONSTRAINT [DF_CMS_Carers_IsActive] DEFAULT (1),
        [CreatedBy]    INT            NOT NULL,
        [CreatedAt]    DATETIME2      NOT NULL CONSTRAINT [DF_CMS_Carers_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [ModifiedBy]   INT            NULL,
        [ModifiedAt]   DATETIME2      NULL,
        [IpAddress]    VARCHAR(45)    NULL,
        [RowVersion]   ROWVERSION     NOT NULL,
        CONSTRAINT [PK_CMS_Carers] PRIMARY KEY CLUSTERED ([CarerId] ASC),
        CONSTRAINT [FK_CMS_Carers_Case]
            FOREIGN KEY ([CaseId]) REFERENCES [dbo].[CMS_Cases] ([CaseId]),
        CONSTRAINT [CK_CMS_Carers_FullName] CHECK (LEN(LTRIM(RTRIM([FullName]))) > 0)
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_Carers_Case]
        ON [dbo].[CMS_Carers] ([CaseId] ASC, [IsActive] ASC);
END
GO
