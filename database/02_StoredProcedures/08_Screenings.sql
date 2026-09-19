/* ============================================================
   AKA-CMS — Sprint 4 stored procedures (08)
   Screening tools & risk stratification.

   Score and risk level are ALWAYS computed server-side from the
   tool's scoring bands; clients never supply them.

   Clinical sync: the scored items are pushed into the EXISTING
   MR_MENTALHEALTH table by updating ONLY the latest visit row
   for the resolved MR number. No MR_MENTALHEALTH row is ever
   inserted here (a screening must not invent clinical visits).
   If no visit row exists, the sync is skipped and
   @MentalHealthSynced = 0.

   Custom error codes:
     50005 concurrency, 50006 invalid transition,
     50007 permission denied, 50008 not found (as before),
     50009 screening validation (item count / item range).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_ScreeningTool_GetAll ----
   Tool catalog with scoring bands. Two result sets: tools, bands. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_ScreeningTool_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [ToolCode], [ToolName], [Description], [ItemCount],
           [MaxItemScore], [MinScore], [MaxScore]
    FROM [dbo].[CMS_ScreeningTools]
    WHERE [IsActive] = 1
    ORDER BY [ToolCode];

    SELECT [ToolCode], [BandCode], [BandName], [MinScore], [MaxScore], [SortOrder]
    FROM [dbo].[CMS_ScreeningRiskBands]
    WHERE [IsActive] = 1
    ORDER BY [ToolCode], [SortOrder];
END
GO

/* ---- sp_CMS_Screening_GetById ----
   Single screening with tool and band names (internal + reuse). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Screening_GetById]
    @ScreeningId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.[ScreeningId], s.[CaseId], s.[CommunityMemberId], s.[ToolCode],
           t.[ToolName], s.[ItemScores], s.[RawScore], s.[RiskLevel],
           b.[BandName] AS [RiskLevelName], s.[MentalHealthSynced],
           s.[MentalHealthCode], s.[ScreenedBy],
           u.[USERNAME] AS [ScreenedByUsername],
           s.[ScreenedAt], s.[IpAddress], s.[RowVersion]
    FROM [dbo].[CMS_Screenings] s
    INNER JOIN [dbo].[CMS_ScreeningTools] t ON t.[ToolCode] = s.[ToolCode]
    LEFT JOIN [dbo].[CMS_ScreeningRiskBands] b
        ON b.[ToolCode] = s.[ToolCode] AND b.[BandCode] = s.[RiskLevel]
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = s.[ScreenedBy]
    WHERE s.[ScreeningId] = @ScreeningId;
END
GO

/* ---- sp_CMS_Screening_GetByCase ----
   All screenings for a case, newest first. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Screening_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    SELECT s.[ScreeningId], s.[CaseId], s.[CommunityMemberId], s.[ToolCode],
           t.[ToolName], s.[ItemScores], s.[RawScore], s.[RiskLevel],
           b.[BandName] AS [RiskLevelName], s.[MentalHealthSynced],
           s.[MentalHealthCode], s.[ScreenedBy],
           u.[USERNAME] AS [ScreenedByUsername],
           s.[ScreenedAt], s.[IpAddress], s.[RowVersion]
    FROM [dbo].[CMS_Screenings] s
    INNER JOIN [dbo].[CMS_ScreeningTools] t ON t.[ToolCode] = s.[ToolCode]
    LEFT JOIN [dbo].[CMS_ScreeningRiskBands] b
        ON b.[ToolCode] = s.[ToolCode] AND b.[BandCode] = s.[RiskLevel]
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = s.[ScreenedBy]
    WHERE s.[CaseId] = @CaseId
    ORDER BY s.[ScreenedAt] DESC, s.[ScreeningId] DESC;
END
GO

/* ---- sp_CMS_Screening_Submit ----
   Validates item scores, computes RawScore + RiskLevel server-side,
   inserts the screening, and syncs into MR_MENTALHEALTH (latest
   visit row for the resolved MR, update-only). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Screening_Submit]
    @CaseId INT,
    @ToolCode VARCHAR(20),
    @ItemScoresJson NVARCHAR(200),
    @PerformedBy INT,
    @IpAddress VARCHAR(50),
    @NewScreeningId INT OUTPUT,
    @MentalHealthSynced BIT OUTPUT,
    @MentalHealthCode VARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @CommunityMemberId INT;

        SELECT @CommunityMemberId = [CommunityMemberId]
        FROM [dbo].[CMS_Cases]
        WHERE [CaseId] = @CaseId AND [IsActive] = 1;

        IF @CommunityMemberId IS NULL
            THROW 50008, 'Case not found.', 1;

        DECLARE @ItemCount INT, @MaxItemScore INT;

        SELECT @ItemCount = [ItemCount], @MaxItemScore = [MaxItemScore]
        FROM [dbo].[CMS_ScreeningTools]
        WHERE [ToolCode] = @ToolCode AND [IsActive] = 1;

        IF @ItemCount IS NULL
            THROW 50008, 'Screening tool not found.', 1;

        /* ---- Parse and validate the JSON item scores ---- */
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

        DECLARE @Q1 INT, @Q2 INT, @Q3 INT, @Q4 INT, @Q5 INT,
                @Q6 INT, @Q7 INT, @Q8 INT, @Q9 INT, @RawScore INT;

        SELECT @Q1 = MAX(CASE WHEN [Idx] = 0 THEN [Score] END),
               @Q2 = MAX(CASE WHEN [Idx] = 1 THEN [Score] END),
               @Q3 = MAX(CASE WHEN [Idx] = 2 THEN [Score] END),
               @Q4 = MAX(CASE WHEN [Idx] = 3 THEN [Score] END),
               @Q5 = MAX(CASE WHEN [Idx] = 4 THEN [Score] END),
               @Q6 = MAX(CASE WHEN [Idx] = 5 THEN [Score] END),
               @Q7 = MAX(CASE WHEN [Idx] = 6 THEN [Score] END),
               @Q8 = MAX(CASE WHEN [Idx] = 7 THEN [Score] END),
               @Q9 = MAX(CASE WHEN [Idx] = 8 THEN [Score] END),
               @RawScore = SUM([Score])
        FROM @Items;

        /* ---- Server-side risk stratification ---- */
        DECLARE @RiskLevel VARCHAR(30), @RiskLevelName NVARCHAR(100);

        SELECT @RiskLevel = [BandCode], @RiskLevelName = [BandName]
        FROM [dbo].[CMS_ScreeningRiskBands]
        WHERE [ToolCode] = @ToolCode AND [IsActive] = 1
          AND @RawScore BETWEEN [MinScore] AND [MaxScore];

        IF @RiskLevel IS NULL
            THROW 50009, 'No risk band covers the computed score.', 1;

        /* ---- Resolve the clinical MR number for this member ---- */
        DECLARE @MrNo VARCHAR(20) = NULL;

        SELECT TOP 1 @MrNo = ISNULL(NULLIF([ResolvedMrNo], ''), [MrNo])
        FROM [dbo].[CMS_HisMrMappings]
        WHERE [CommunityMemberId] = @CommunityMemberId AND [IsActive] = 1;

        /* Fall back to the MR stored directly on the member row
           (members registered with a known MR do not always have
           a HisMrMappings row). */
        IF @MrNo IS NULL
        BEGIN
            SELECT @MrNo = NULLIF([MrNo], '')
            FROM [dbo].[CMS_CommunityMembers]
            WHERE [MemberId] = @CommunityMemberId;
        END

        /* ---- Sync into MR_MENTALHEALTH (update latest visit row only) ---- */
        SET @MentalHealthSynced = 0;
        SET @MentalHealthCode = NULL;

        IF @MrNo IS NOT NULL
        BEGIN
            DECLARE @Code VARCHAR(20) = NULL;

            SELECT TOP 1 @Code = [CODE]
            FROM [dbo].[MR_MENTALHEALTH]
            WHERE [MRNO] = @MrNo
            ORDER BY [VISITNUMBER] DESC;

            IF @Code IS NOT NULL
            BEGIN
                DECLARE @UserName VARCHAR(30) = CAST(@PerformedBy AS VARCHAR(30));

                SELECT @UserName = [USERNAME]
                FROM [dbo].[USERS]
                WHERE [USERID] = @PerformedBy;

                IF @ToolCode = 'PHQ9'
                BEGIN
                    UPDATE [dbo].[MR_MENTALHEALTH]
                    SET [PHQ9Q1] = @Q1, [PHQ9Q2] = @Q2, [PHQ9Q3] = @Q3,
                        [PHQ9Q4] = @Q4, [PHQ9Q5] = @Q5, [PHQ9Q6] = @Q6,
                        [PHQ9Q7] = @Q7, [PHQ9Q8] = @Q8, [PHQ9Q9] = @Q9,
                        [PHQ9QTotal] = @RawScore,
                        [UPDATEDDATE] = SYSUTCDATETIME(),
                        [UPDATEDBY] = @UserName,
                        [UPDATERIPADDRESS] = @IpAddress
                    WHERE [CODE] = @Code;
                END
                ELSE IF @ToolCode = 'GAD7'
                BEGIN
                    UPDATE [dbo].[MR_MENTALHEALTH]
                    SET [GAD71] = @Q1, [GAD72] = @Q2, [GAD73] = @Q3,
                        [GAD74] = @Q4, [GAD75] = @Q5, [GAD76] = @Q6,
                        [GAD77] = @Q7,
                        [GAD7Total] = @RawScore,
                        [UPDATEDDATE] = SYSUTCDATETIME(),
                        [UPDATEDBY] = @UserName,
                        [UPDATERIPADDRESS] = @IpAddress
                    WHERE [CODE] = @Code;
                END

                SET @MentalHealthSynced = 1;
                SET @MentalHealthCode = @Code;
            END
        END

        INSERT INTO [dbo].[CMS_Screenings]
            ([CaseId], [CommunityMemberId], [ToolCode], [ItemScores],
             [RawScore], [RiskLevel], [MentalHealthSynced], [MentalHealthCode],
             [ScreenedBy], [IpAddress])
        VALUES
            (@CaseId, @CommunityMemberId, @ToolCode, @ItemScoresJson,
             @RawScore, @RiskLevel, @MentalHealthSynced, @MentalHealthCode,
             @PerformedBy, @IpAddress);

        SET @NewScreeningId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Screenings', CAST(@NewScreeningId AS VARCHAR(50)), 'SUBMIT', @PerformedBy,
                @ToolCode + ' score=' + CAST(@RawScore AS VARCHAR(10)) + ' risk=' + @RiskLevel +
                ' mhSynced=' + CAST(@MentalHealthSynced AS VARCHAR(1)));

        COMMIT TRAN;

        EXEC [dbo].[sp_CMS_Screening_GetById] @ScreeningId = @NewScreeningId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
