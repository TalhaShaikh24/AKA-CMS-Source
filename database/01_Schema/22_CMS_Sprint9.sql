/* ============================================================
   AKA-CMS — Sprint 9: Master Data / Workflow Config / Reports
   Schema deltas only (reuses existing CMS tables wherever possible).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- CMS_WorkflowTransitions: RowVersion for admin enable/disable concurrency ---- */
IF COL_LENGTH(N'[dbo].[CMS_WorkflowTransitions]', N'RowVersion') IS NULL
BEGIN
    ALTER TABLE [dbo].[CMS_WorkflowTransitions]
        ADD [RowVersion] ROWVERSION NOT NULL;
END
GO
