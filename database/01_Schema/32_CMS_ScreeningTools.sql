/* ==========================================================================
   CMS Screening Tools — dynamic question management
   Extends the existing CMS_ScreeningTools (08_CMS_Screenings.sql) with
   a questions table keyed by ToolCode. Safe to re-run.
   ========================================================================== */

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'CMS_ScreeningToolQuestions' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE [dbo].[CMS_ScreeningToolQuestions] (
        [QuestionId]   INT IDENTITY(1,1) NOT NULL,
        [ToolCode]     VARCHAR(20) NOT NULL,
        [QuestionText] NVARCHAR(500) NOT NULL,
        [SortOrder]    INT NOT NULL CONSTRAINT [DF_CMS_ScreeningToolQuestions_SortOrder] DEFAULT (0),
        [OptionsJson]  NVARCHAR(MAX) NOT NULL,
        CONSTRAINT [PK_CMS_ScreeningToolQuestions] PRIMARY KEY ([QuestionId]),
        CONSTRAINT [FK_CMS_ScreeningToolQuestions_Tool] FOREIGN KEY ([ToolCode])
            REFERENCES [dbo].[CMS_ScreeningTools] ([ToolCode])
    );
    CREATE INDEX [IX_CMS_ScreeningToolQuestions_ToolCode] ON [dbo].[CMS_ScreeningToolQuestions] ([ToolCode], [SortOrder]);
END
GO

/* SortOrder for admin ordering (if not present) */
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[CMS_ScreeningTools]') AND name = 'SortOrder')
BEGIN
    ALTER TABLE [dbo].[CMS_ScreeningTools] ADD [SortOrder] INT NOT NULL CONSTRAINT [DF_CMS_ScreeningTools_SortOrder] DEFAULT (0);
END
GO
