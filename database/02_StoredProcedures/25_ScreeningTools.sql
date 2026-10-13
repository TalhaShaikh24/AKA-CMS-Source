/* ==========================================================================
   CMS Screening Tools — dynamic management stored procedures
   ========================================================================== */

/* ---------- list active tools with questions (for forms) ---------- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_ScreeningTool_GetActive]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        t.[ToolCode],
        t.[ToolName],
        t.[Description],
        t.[SortOrder],
        (
            SELECT q.[QuestionText] AS [text],
                   JSON_QUERY(q.[OptionsJson]) AS [options]
            FROM [dbo].[CMS_ScreeningToolQuestions] q
            WHERE q.[ToolCode] = t.[ToolCode]
            ORDER BY q.[SortOrder], q.[QuestionId]
            FOR JSON PATH
        ) AS [QuestionsJson]
    FROM [dbo].[CMS_ScreeningTools] t
    WHERE t.[IsActive] = 1
    ORDER BY t.[SortOrder], t.[ToolCode];
END
GO

/* ---------- admin list (all tools) ---------- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_ScreeningTool_GetAllAdmin]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        t.[ToolCode],
        t.[ToolName],
        t.[Description],
        t.[ItemCount],
        t.[IsActive],
        t.[SortOrder],
        (SELECT COUNT(*) FROM [dbo].[CMS_ScreeningToolQuestions] q WHERE q.[ToolCode] = t.[ToolCode]) AS [QuestionCount]
    FROM [dbo].[CMS_ScreeningTools] t
    ORDER BY t.[SortOrder], t.[ToolCode];
END
GO

/* ---------- get one tool with questions ---------- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_ScreeningTool_GetDetail]
    @ToolCode VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_ScreeningTools] WHERE [ToolCode] = @ToolCode)
        THROW 50008, 'Screening tool not found.', 1;

    SELECT
        t.[ToolCode], t.[ToolName], t.[Description], t.[ItemCount], t.[IsActive], t.[SortOrder],
        (
            SELECT q.[QuestionId], q.[QuestionText], q.[SortOrder],
                   JSON_QUERY(q.[OptionsJson]) AS [Options]
            FROM [dbo].[CMS_ScreeningToolQuestions] q
            WHERE q.[ToolCode] = t.[ToolCode]
            ORDER BY q.[SortOrder], q.[QuestionId]
            FOR JSON PATH
        ) AS [QuestionsJson]
    FROM [dbo].[CMS_ScreeningTools] t
    WHERE t.[ToolCode] = @ToolCode;
END
GO

/* ---------- create tool with questions ---------- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_ScreeningTool_CreateFull]
    @ToolCode      VARCHAR(20),
    @ToolName      NVARCHAR(100),
    @Description   NVARCHAR(500) = NULL,
    @ItemCount     INT,
    @MaxItemScore  INT = 3,
    @SortOrder     INT = 0,
    @QuestionsJson NVARCHAR(MAX) = NULL,  /* [{text, options:[{t,v}]}] */
    @PerformedBy   INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        IF EXISTS (SELECT 1 FROM [dbo].[CMS_ScreeningTools] WHERE [ToolCode] = @ToolCode)
            THROW 50009, 'A screening tool with this code already exists.', 1;

        INSERT INTO [dbo].[CMS_ScreeningTools]
            ([ToolCode], [ToolName], [Description], [ItemCount], [MaxItemScore], [MinScore], [MaxScore], [IsActive], [SortOrder])
        VALUES (@ToolCode, @ToolName, @Description, @ItemCount, @MaxItemScore, 0, @ItemCount * @MaxItemScore, 1, @SortOrder);

        IF (@QuestionsJson IS NOT NULL)
        BEGIN
            INSERT INTO [dbo].[CMS_ScreeningToolQuestions] ([ToolCode], [QuestionText], [SortOrder], [OptionsJson])
            SELECT @ToolCode,
                   JSON_VALUE(value, '$.text'),
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1,
                   JSON_QUERY(value, '$.options')
            FROM OPENJSON(@QuestionsJson);
        END

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_ScreeningTools', @ToolCode, 'INSERT', @PerformedBy, @ToolName);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---------- update tool (meta + replace questions) ---------- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_ScreeningTool_UpdateFull]
    @ToolCode      VARCHAR(20),
    @ToolName      NVARCHAR(100),
    @Description   NVARCHAR(500) = NULL,
    @IsActive      BIT,
    @SortOrder     INT = 0,
    @QuestionsJson NVARCHAR(MAX) = NULL,  /* NULL = keep existing questions */
    @PerformedBy   INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_ScreeningTools] WHERE [ToolCode] = @ToolCode)
            THROW 50008, 'Screening tool not found.', 1;

        UPDATE [dbo].[CMS_ScreeningTools]
        SET [ToolName] = @ToolName,
            [Description] = @Description,
            [IsActive] = @IsActive,
            [SortOrder] = @SortOrder
        WHERE [ToolCode] = @ToolCode;

        IF (@QuestionsJson IS NOT NULL)
        BEGIN
            DELETE FROM [dbo].[CMS_ScreeningToolQuestions] WHERE [ToolCode] = @ToolCode;
            INSERT INTO [dbo].[CMS_ScreeningToolQuestions] ([ToolCode], [QuestionText], [SortOrder], [OptionsJson])
            SELECT @ToolCode,
                   JSON_VALUE(value, '$.text'),
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1,
                   JSON_QUERY(value, '$.options')
            FROM OPENJSON(@QuestionsJson);
        END

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_ScreeningTools', @ToolCode, 'UPDATE', @PerformedBy, @ToolName);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
