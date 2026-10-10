/* ==========================================================================
   CMS Screenings — UPDATE (re-score on edit)
   ========================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Screening_Update]
    @ScreeningId INT,
    @ItemScoresJson NVARCHAR(200),
    @RowVersion BINARY(8),
    @PerformedBy INT,
    @IpAddress VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @ToolCode VARCHAR(20), @CaseId INT;

        SELECT @ToolCode = [ToolCode], @CaseId = [CaseId]
        FROM [dbo].[CMS_Screenings]
        WHERE [ScreeningId] = @ScreeningId;

        IF @ToolCode IS NULL
            THROW 50008, 'Screening not found.', 1;

        /* RowVersion concurrency check */
        IF NOT EXISTS (
            SELECT 1 FROM [dbo].[CMS_Screenings]
            WHERE [ScreeningId] = @ScreeningId AND [RowVersion] = @RowVersion)
            THROW 50005, 'This screening was modified by another user. Please reload and try again.', 1;

        DECLARE @ItemCount INT, @MaxItemScore INT;

        SELECT @ItemCount = [ItemCount], @MaxItemScore = [MaxItemScore]
        FROM [dbo].[CMS_ScreeningTools]
        WHERE [ToolCode] = @ToolCode AND [IsActive] = 1;

        IF @ItemCount IS NULL
            THROW 50008, 'Screening tool not found.', 1;

        IF ISNULL(@ItemScoresJson, '') = '' OR ISJSON(@ItemScoresJson) <> 1
            THROW 50009, 'ItemScores must be a JSON array of item scores.', 1;

        DECLARE @Items TABLE ([Idx] INT PRIMARY KEY, [Score] INT);

        INSERT INTO @Items ([Idx], [Score])
        SELECT CAST([key] AS INT), TRY_CAST([value] AS INT)
        FROM OPENJSON(@ItemScoresJson);

        IF (SELECT COUNT(*) FROM @Items) <> @ItemCount
            THROW 50009, 'Item score count does not match the tool definition.', 1;

        IF EXISTS (SELECT 1 FROM @Items WHERE [Score] IS NULL OR [Score] < 0 OR [Score] > @MaxItemScore)
            THROW 50009, 'Each item score must be an integer within the tool range.', 1;

        /* SBQ-R per-item ranges */
        IF @ToolCode = 'SBQR'
        BEGIN
            IF EXISTS (SELECT 1 FROM @Items
                       WHERE ([Idx] = 0 AND ([Score] < 1 OR [Score] > 4))
                          OR ([Idx] = 1 AND ([Score] < 1 OR [Score] > 5))
                          OR ([Idx] = 2 AND ([Score] < 1 OR [Score] > 3))
                          OR ([Idx] = 3 AND ([Score] < 0 OR [Score] > 6)))
                THROW 50009, 'SBQ-R items must use their published per-item ranges (1-4, 1-5, 1-3, 0-6).', 1;
        END

        DECLARE @RawScore INT;
        SELECT @RawScore = SUM([Score]) FROM @Items;

        /* Risk band lookup */
        DECLARE @RiskLevel VARCHAR(30), @RiskLevelName NVARCHAR(100);

        SELECT TOP 1 @RiskLevel = [BandCode], @RiskLevelName = [BandName]
        FROM [dbo].[CMS_ScreeningRiskBands]
        WHERE [ToolCode] = @ToolCode
          AND [IsActive] = 1
          AND @RawScore BETWEEN [MinScore] AND [MaxScore]
        ORDER BY [SortOrder];

        IF @RiskLevel IS NULL
        BEGIN
            SET @RiskLevel = 'UNKNOWN';
            SET @RiskLevelName = 'Unknown';
        END

        UPDATE [dbo].[CMS_Screenings]
        SET [ItemScores] = @ItemScoresJson,
            [RawScore] = @RawScore,
            [RiskLevel] = @RiskLevel,
            [ScreenedBy] = @PerformedBy,
            [ScreenedAt] = SYSUTCDATETIME(),
            [IpAddress] = @IpAddress
        WHERE [ScreeningId] = @ScreeningId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Screenings', CAST(@ScreeningId AS VARCHAR(50)), 'UPDATE', @PerformedBy,
                @ToolCode + ' score=' + CAST(@RawScore AS VARCHAR(10)) + ' risk=' + @RiskLevel);

        COMMIT TRAN;

        EXEC [dbo].[sp_CMS_Screening_GetById] @ScreeningId = @ScreeningId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
