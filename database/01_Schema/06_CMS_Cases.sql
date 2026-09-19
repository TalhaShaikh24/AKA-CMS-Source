/* ============================================================
   AKA-CMS — Sprint 3: case lifecycle (workflow engine) tables.

   Source: Figure 3 "IMHP - End-to-End Clinical & Case Management
   Workflow" in the client wireframing PDF
   (Proposed_Wireframing_Logic___UML_for_CMS-IMHP_Revised_240326__1.pdf),
   cross-verified against the flowchart image and the technical
   proposal ("configurable workflow engine will manage case
   lifecycle transitions"). The user's IMHP-CMS_Workflow.xlsx
   transcription was used as a secondary reference only.

   Existing [CASE] in CO-HIS is a small dictionary table, NOT the
   case aggregate — these CMS_ tables are new; nothing existing is
   altered.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- Workflow states (case lifecycle nodes) ---- */
IF OBJECT_ID(N'[dbo].[CMS_WorkflowStates]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_WorkflowStates] (
        [StateCode]   VARCHAR(30)  NOT NULL,
        [StateName]   NVARCHAR(100) NOT NULL,
        [Description] NVARCHAR(500) NULL,
        [IsInitial]   BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowStates_IsInitial] DEFAULT (0),
        [IsTerminal]  BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowStates_IsTerminal] DEFAULT (0),
        [SortOrder]   INT NOT NULL CONSTRAINT [DF_CMS_WorkflowStates_SortOrder] DEFAULT (0),
        CONSTRAINT [PK_CMS_WorkflowStates] PRIMARY KEY CLUSTERED ([StateCode])
    );
END
GO

/* ---- Workflow transitions (state machine edges) ---- */
IF OBJECT_ID(N'[dbo].[CMS_WorkflowTransitions]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_WorkflowTransitions] (
        [TransitionId]         INT IDENTITY(1,1) NOT NULL,
        [FromState]            VARCHAR(30)  NOT NULL,
        [ActionCode]           VARCHAR(50)  NOT NULL,
        [ActionName]           NVARCHAR(100) NOT NULL,
        [ToState]              VARCHAR(30)  NOT NULL,
        [RequiredPermissionName] VARCHAR(100) NOT NULL,
        [SortOrder]            INT NOT NULL CONSTRAINT [DF_CMS_WorkflowTransitions_SortOrder] DEFAULT (0),
        [IsActive]             BIT NOT NULL CONSTRAINT [DF_CMS_WorkflowTransitions_IsActive] DEFAULT (1),
        CONSTRAINT [PK_CMS_WorkflowTransitions] PRIMARY KEY CLUSTERED ([TransitionId]),
        CONSTRAINT [UQ_CMS_WorkflowTransitions_FromAction] UNIQUE NONCLUSTERED ([FromState], [ActionCode]),
        CONSTRAINT [FK_CMS_WorkflowTransitions_FromState]
            FOREIGN KEY ([FromState]) REFERENCES [dbo].[CMS_WorkflowStates]([StateCode]),
        CONSTRAINT [FK_CMS_WorkflowTransitions_ToState]
            FOREIGN KEY ([ToState]) REFERENCES [dbo].[CMS_WorkflowStates]([StateCode])
    );
END
GO

/* ---- Case number sequence: CMS-YYYY-###### ---- */
IF NOT EXISTS (SELECT 1 FROM sys.sequences WHERE [name] = N'CMS_CaseNumberSeq')
BEGIN
    CREATE SEQUENCE [dbo].[CMS_CaseNumberSeq] AS INT START WITH 1 INCREMENT BY 1;
END
GO

/* ---- CMS case aggregate ---- */
IF OBJECT_ID(N'[dbo].[CMS_Cases]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_Cases] (
        [CaseId]            INT IDENTITY(1,1) NOT NULL,
        [CaseNumber]        VARCHAR(30)  NOT NULL,
        [CommunityMemberId] INT NOT NULL,
        [SourceType]        VARCHAR(30)  NOT NULL,
        [Status]            VARCHAR(30)  NOT NULL,
        [CurrentStep]       VARCHAR(50)  NULL,
        [AssignedToUserId]  INT NULL,
        [PriorityLevel]     VARCHAR(20)  NULL,
        [Notes]             NVARCHAR(2000) NULL,
        [RowVersion]        ROWVERSION NOT NULL,
        [IsActive]          BIT NOT NULL CONSTRAINT [DF_CMS_Cases_IsActive] DEFAULT (1),
        [CreatedBy]         INT NOT NULL,
        [CreatedAt]         DATETIME2 NOT NULL CONSTRAINT [DF_CMS_Cases_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [ModifiedBy]        INT NULL,
        [ModifiedAt]        DATETIME2 NULL,
        [IpAddress]         VARCHAR(50) NULL,
        CONSTRAINT [PK_CMS_Cases] PRIMARY KEY CLUSTERED ([CaseId]),
        CONSTRAINT [UQ_CMS_Cases_CaseNumber] UNIQUE NONCLUSTERED ([CaseNumber]),
        CONSTRAINT [FK_CMS_Cases_CommunityMember]
            FOREIGN KEY ([CommunityMemberId]) REFERENCES [dbo].[CMS_CommunityMembers]([MemberId]),
        CONSTRAINT [FK_CMS_Cases_Status]
            FOREIGN KEY ([Status]) REFERENCES [dbo].[CMS_WorkflowStates]([StateCode])
    );
END
GO

/* ---- Case history (workflow transition trail) ---- */
IF OBJECT_ID(N'[dbo].[CMS_CaseHistories]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_CaseHistories] (
        [HistoryId]   INT IDENTITY(1,1) NOT NULL,
        [CaseId]      INT NOT NULL,
        [FromState]   VARCHAR(30)  NOT NULL,
        [ToState]     VARCHAR(30)  NOT NULL,
        [ActionCode]  VARCHAR(50)  NOT NULL,
        [Comment]     NVARCHAR(1000) NULL,
        [PerformedBy] INT NOT NULL,
        [PerformedAt] DATETIME2 NOT NULL CONSTRAINT [DF_CMS_CaseHistories_PerformedAt] DEFAULT (SYSUTCDATETIME()),
        [IpAddress]   VARCHAR(50) NULL,
        CONSTRAINT [PK_CMS_CaseHistories] PRIMARY KEY CLUSTERED ([HistoryId]),
        CONSTRAINT [FK_CMS_CaseHistories_Case]
            FOREIGN KEY ([CaseId]) REFERENCES [dbo].[CMS_Cases]([CaseId])
    );

    CREATE INDEX [IX_CMS_CaseHistories_CaseId] ON [dbo].[CMS_CaseHistories] ([CaseId], [HistoryId]);
END
GO
