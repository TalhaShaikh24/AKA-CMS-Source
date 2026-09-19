/* ============================================================
   AKA-CMS — Sprint 4 schema (08)
   Screening tools & risk stratification.

   CMS_ScreeningTools      : screening tool catalog (PHQ-9, GAD-7)
   CMS_ScreeningRiskBands   : server-side scoring bands per tool
   CMS_Screenings           : submitted screenings (score/risk computed
                              server-side, never accepted from client)

   Clinical data sync: scores are pushed into the EXISTING
   MR_MENTALHEALTH table (update of the latest visit row only).
   MR_MENTALHEALTH is never altered structurally and no new
   clinical rows are invented by the screening procedures.
   Safe to re-run (guarded by OBJECT_ID checks).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[dbo].[CMS_ScreeningTools]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_ScreeningTools](
        [ToolCode]     VARCHAR(20)   NOT NULL,
        [ToolName]     NVARCHAR(100) NOT NULL,
        [Description]  NVARCHAR(500) NULL,
        [ItemCount]    INT           NOT NULL,
        [MaxItemScore] INT           NOT NULL CONSTRAINT [DF_CMS_ScreeningTools_MaxItemScore] DEFAULT (3),
        [MinScore]     INT           NOT NULL CONSTRAINT [DF_CMS_ScreeningTools_MinScore] DEFAULT (0),
        [MaxScore]     INT           NOT NULL,
        [IsActive]     BIT           NOT NULL CONSTRAINT [DF_CMS_ScreeningTools_IsActive] DEFAULT (1),
        CONSTRAINT [PK_CMS_ScreeningTools] PRIMARY KEY CLUSTERED ([ToolCode] ASC),
        CONSTRAINT [CK_CMS_ScreeningTools_ItemCount] CHECK ([ItemCount] BETWEEN 1 AND 30),
        CONSTRAINT [CK_CMS_ScreeningTools_ScoreRange] CHECK ([MinScore] <= [MaxScore])
    );
END
GO

IF OBJECT_ID(N'[dbo].[CMS_ScreeningRiskBands]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_ScreeningRiskBands](
        [RiskBandId] INT IDENTITY(1,1) NOT NULL,
        [ToolCode]   VARCHAR(20)   NOT NULL,
        [BandCode]   VARCHAR(30)   NOT NULL,
        [BandName]   NVARCHAR(100) NOT NULL,
        [MinScore]   INT           NOT NULL,
        [MaxScore]   INT           NOT NULL,
        [SortOrder]  INT           NOT NULL CONSTRAINT [DF_CMS_ScreeningRiskBands_SortOrder] DEFAULT (0),
        [IsActive]   BIT           NOT NULL CONSTRAINT [DF_CMS_ScreeningRiskBands_IsActive] DEFAULT (1),
        CONSTRAINT [PK_CMS_ScreeningRiskBands] PRIMARY KEY CLUSTERED ([RiskBandId] ASC),
        CONSTRAINT [FK_CMS_ScreeningRiskBands_Tool]
            FOREIGN KEY ([ToolCode]) REFERENCES [dbo].[CMS_ScreeningTools] ([ToolCode]),
        CONSTRAINT [CK_CMS_ScreeningRiskBands_Range] CHECK ([MinScore] <= [MaxScore])
    );
    CREATE UNIQUE NONCLUSTERED INDEX [UX_CMS_ScreeningRiskBands_Tool_Band]
        ON [dbo].[CMS_ScreeningRiskBands] ([ToolCode] ASC, [BandCode] ASC);
END
GO

IF OBJECT_ID(N'[dbo].[CMS_Screenings]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_Screenings](
        [ScreeningId]       INT IDENTITY(1,1) NOT NULL,
        [CaseId]            INT           NOT NULL,
        [CommunityMemberId] INT           NOT NULL,
        [ToolCode]          VARCHAR(20)   NOT NULL,
        [ItemScores]        NVARCHAR(200) NOT NULL,
        [RawScore]          INT           NOT NULL,
        [RiskLevel]         VARCHAR(30)   NOT NULL,
        [MentalHealthSynced] BIT          NOT NULL CONSTRAINT [DF_CMS_Screenings_MentalHealthSynced] DEFAULT (0),
        [MentalHealthCode]  VARCHAR(20)   NULL,
        [ScreenedBy]        INT           NOT NULL,
        [ScreenedAt]        DATETIME2     NOT NULL CONSTRAINT [DF_CMS_Screenings_ScreenedAt] DEFAULT (SYSUTCDATETIME()),
        [IpAddress]         VARCHAR(50)   NULL,
        [RowVersion]        ROWVERSION    NOT NULL,
        CONSTRAINT [PK_CMS_Screenings] PRIMARY KEY CLUSTERED ([ScreeningId] ASC),
        CONSTRAINT [FK_CMS_Screenings_Case]
            FOREIGN KEY ([CaseId]) REFERENCES [dbo].[CMS_Cases] ([CaseId]),
        CONSTRAINT [FK_CMS_Screenings_CommunityMember]
            FOREIGN KEY ([CommunityMemberId]) REFERENCES [dbo].[CMS_CommunityMembers] ([MemberId]),
        CONSTRAINT [FK_CMS_Screenings_Tool]
            FOREIGN KEY ([ToolCode]) REFERENCES [dbo].[CMS_ScreeningTools] ([ToolCode])
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_Screenings_Case]
        ON [dbo].[CMS_Screenings] ([CaseId] ASC, [ScreenedAt] DESC);
END
GO
