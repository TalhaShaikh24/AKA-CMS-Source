/* ============================================================
   AKA-CMS — Module 1 remainder procedures (11):
   awareness sessions, session participants, case source mapping.

   Custom THROW numbers (project-wide):
     50005 - row-version mismatch (optimistic concurrency)
     50008 - entity not found
     50009 - domain validation failure (400)
     50010 - invalid domain value (400)
     50011 - duplicate/conflict (409)

   Every write proc: TRY/CATCH + transaction + CMS_AuditLogs row.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_AwarenessSession_Create ----
   Creates a session; the SessionCode is auto-generated
   (SES-YYYY-######), per Technical Proposal Phase 1
   "Auto Session ID Generator". */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_AwarenessSession_Create]
    @Title NVARCHAR(200),
    @FacilityCode VARCHAR(20) = NULL,
    @SessionDate DATE,
    @ConductedBy INT = NULL,
    @Topic NVARCHAR(200) = NULL,
    @TargetGroup NVARCHAR(100) = NULL,
    @Venue NVARCHAR(200) = NULL,
    @MaleCount INT = 0,
    @FemaleCount INT = 0,
    @OtherCount INT = 0,
    @Notes NVARCHAR(2000) = NULL,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewSessionId INT OUTPUT,
    @NewSessionCode VARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF @Title IS NULL OR LTRIM(RTRIM(@Title)) = ''
            THROW 50009, 'Title is required.', 1;
        IF @SessionDate IS NULL
            THROW 50009, 'SessionDate is required.', 1;
        IF @MaleCount < 0 OR @FemaleCount < 0 OR @OtherCount < 0
            THROW 50009, 'Gender counts cannot be negative.', 1;

        SET @NewSessionCode =
            'SES-' + CAST(YEAR(SYSUTCDATETIME()) AS VARCHAR(4)) + '-'
            + RIGHT('000000' + CAST(NEXT VALUE FOR [dbo].[CMS_AwarenessSessionSeq] AS VARCHAR(10)), 6);

        INSERT INTO [dbo].[CMS_AwarenessSessions]
            ([SessionCode], [Title], [FacilityCode], [SessionDate], [ConductedBy],
             [Topic], [TargetGroup], [Venue], [MaleCount], [FemaleCount], [OtherCount],
             [Notes], [IsActive], [CreatedBy], [IpAddress])
        VALUES
            (@NewSessionCode, @Title, @FacilityCode, @SessionDate, @ConductedBy,
             @Topic, @TargetGroup, @Venue, @MaleCount, @FemaleCount, @OtherCount,
             @Notes, 1, @CreatedBy, @IpAddress);

        SET @NewSessionId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_AwarenessSessions', CAST(@NewSessionId AS VARCHAR(50)), 'INSERT', @CreatedBy, @NewSessionCode);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_AwarenessSession_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_AwarenessSession_GetById]
    @SessionId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.[SessionId], s.[SessionCode], s.[Title], s.[FacilityCode], s.[SessionDate],
           s.[ConductedBy], s.[Topic], s.[TargetGroup], s.[Venue],
           s.[MaleCount], s.[FemaleCount], s.[OtherCount], s.[Notes],
           s.[RowVersion], s.[IsActive], s.[CreatedAt], s.[UpdatedAt],
           (SELECT COUNT(1) FROM [dbo].[CMS_SessionParticipants] p
            WHERE p.[SessionId] = s.[SessionId] AND p.[IsActive] = 1) AS [ParticipantCount]
    FROM [dbo].[CMS_AwarenessSessions] s
    WHERE s.[SessionId] = @SessionId AND s.[IsActive] = 1;
END
GO

/* ---- sp_CMS_AwarenessSession_GetList ----
   Filterable by facility and date range. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_AwarenessSession_GetList]
    @FacilityCode VARCHAR(20) = NULL,
    @FromDate DATE = NULL,
    @ToDate DATE = NULL,
    @Top INT = 50
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (CASE WHEN @Top BETWEEN 1 AND 500 THEN @Top ELSE 50 END)
           s.[SessionId], s.[SessionCode], s.[Title], s.[FacilityCode], s.[SessionDate],
           s.[ConductedBy], s.[Topic], s.[TargetGroup], s.[Venue],
           s.[MaleCount], s.[FemaleCount], s.[OtherCount], s.[Notes],
           s.[RowVersion], s.[IsActive], s.[CreatedAt], s.[UpdatedAt],
           (SELECT COUNT(1) FROM [dbo].[CMS_SessionParticipants] p
            WHERE p.[SessionId] = s.[SessionId] AND p.[IsActive] = 1) AS [ParticipantCount]
    FROM [dbo].[CMS_AwarenessSessions] s
    WHERE s.[IsActive] = 1
      AND (@FacilityCode IS NULL OR s.[FacilityCode] = @FacilityCode)
      AND (@FromDate IS NULL OR s.[SessionDate] >= @FromDate)
      AND (@ToDate IS NULL OR s.[SessionDate] <= @ToDate)
    ORDER BY s.[SessionDate] DESC, s.[SessionId] DESC;
END
GO

/* ---- sp_CMS_AwarenessSession_Update ----
   RowVersion-checked detail update (never changes the SessionCode). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_AwarenessSession_Update]
    @SessionId INT,
    @Title NVARCHAR(200),
    @FacilityCode VARCHAR(20) = NULL,
    @SessionDate DATE,
    @Topic NVARCHAR(200) = NULL,
    @TargetGroup NVARCHAR(100) = NULL,
    @Venue NVARCHAR(200) = NULL,
    @MaleCount INT = 0,
    @FemaleCount INT = 0,
    @OtherCount INT = 0,
    @Notes NVARCHAR(2000) = NULL,
    @RowVersion BINARY(8),
    @PerformedBy INT,
    @IpAddress VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_AwarenessSessions]
                       WHERE [SessionId] = @SessionId AND [IsActive] = 1)
            THROW 50008, 'Awareness session not found.', 1;

        IF @Title IS NULL OR LTRIM(RTRIM(@Title)) = ''
            THROW 50009, 'Title is required.', 1;
        IF @MaleCount < 0 OR @FemaleCount < 0 OR @OtherCount < 0
            THROW 50009, 'Gender counts cannot be negative.', 1;

        UPDATE [dbo].[CMS_AwarenessSessions]
        SET [Title] = @Title,
            [FacilityCode] = @FacilityCode,
            [SessionDate] = @SessionDate,
            [Topic] = @Topic,
            [TargetGroup] = @TargetGroup,
            [Venue] = @Venue,
            [MaleCount] = @MaleCount,
            [FemaleCount] = @FemaleCount,
            [OtherCount] = @OtherCount,
            [Notes] = @Notes,
            [UpdatedAt] = SYSUTCDATETIME()
        WHERE [SessionId] = @SessionId
          AND [RowVersion] = @RowVersion;

        IF @@ROWCOUNT = 0
            THROW 50005, 'The session was modified by another user.', 1;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_AwarenessSessions', CAST(@SessionId AS VARCHAR(50)), 'UPDATE', @PerformedBy, @Title);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_SessionParticipant_Register ----
   Idempotent: re-registering the same member (or the same walk-in
   name) in the same session returns the existing row with @WasNew=0.
   Either @CommunityMemberId (registered member) or
   @ParticipantName (walk-in fallback) must be supplied. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_SessionParticipant_Register]
    @SessionId INT,
    @CommunityMemberId INT = NULL,
    @ParticipantName NVARCHAR(200) = NULL,
    @Attended BIT = 1,
    @ConsentedToScreening BIT = 0,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewParticipantId INT OUTPUT,
    @WasNew BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_AwarenessSessions]
                       WHERE [SessionId] = @SessionId AND [IsActive] = 1)
            THROW 50008, 'Awareness session not found.', 1;

        IF @CommunityMemberId IS NULL AND (@ParticipantName IS NULL OR LTRIM(RTRIM(@ParticipantName)) = '')
            THROW 50009, 'CommunityMemberId or ParticipantName is required.', 1;

        IF @CommunityMemberId IS NOT NULL
            AND NOT EXISTS (SELECT 1 FROM [dbo].[CMS_CommunityMembers]
                            WHERE [MemberId] = @CommunityMemberId AND [IsActive] = 1)
            THROW 50008, 'Community member not found.', 1;

        SELECT @NewParticipantId = [ParticipantId]
        FROM [dbo].[CMS_SessionParticipants]
        WHERE [SessionId] = @SessionId AND [IsActive] = 1
          AND ((@CommunityMemberId IS NOT NULL AND [CommunityMemberId] = @CommunityMemberId)
               OR (@CommunityMemberId IS NULL AND [ParticipantName] = @ParticipantName));

        IF @NewParticipantId IS NOT NULL
        BEGIN
            SET @WasNew = 0;
        END
        ELSE
        BEGIN
            INSERT INTO [dbo].[CMS_SessionParticipants]
                ([SessionId], [CommunityMemberId], [ParticipantName], [Attended],
                 [ConsentedToScreening], [IsActive], [CreatedBy], [IpAddress])
            VALUES
                (@SessionId, @CommunityMemberId, @ParticipantName, @Attended,
                 @ConsentedToScreening, 1, @CreatedBy, @IpAddress);

            SET @NewParticipantId = SCOPE_IDENTITY();
            SET @WasNew = 1;

            INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
            VALUES ('CMS_SessionParticipants', CAST(@NewParticipantId AS VARCHAR(50)), 'INSERT', @CreatedBy,
                    'Session ' + CAST(@SessionId AS VARCHAR(20)));
        END

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_SessionParticipant_GetList ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_SessionParticipant_GetList]
    @SessionId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.[ParticipantId], p.[SessionId], p.[CommunityMemberId],
           cm.[FullName] AS [MemberName],
           p.[ParticipantName], p.[Attended], p.[ConsentedToScreening],
           p.[ScreeningId], p.[RowVersion], p.[IsActive], p.[CreatedAt]
    FROM [dbo].[CMS_SessionParticipants] p
    LEFT JOIN [dbo].[CMS_CommunityMembers] cm ON cm.[MemberId] = p.[CommunityMemberId]
    WHERE p.[SessionId] = @SessionId AND p.[IsActive] = 1
    ORDER BY p.[ParticipantId];
END
GO

/* ---- sp_CMS_SessionParticipant_LinkScreening ----
   Phase 2 (Case Identification): links a screening administered
   in-session to the participant row. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_SessionParticipant_LinkScreening]
    @ParticipantId INT,
    @ScreeningId INT,
    @PerformedBy INT,
    @IpAddress VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_SessionParticipants]
                       WHERE [ParticipantId] = @ParticipantId AND [IsActive] = 1)
            THROW 50008, 'Session participant not found.', 1;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Screenings] WHERE [ScreeningId] = @ScreeningId)
            THROW 50008, 'Screening not found.', 1;

        UPDATE [dbo].[CMS_SessionParticipants]
        SET [ScreeningId] = @ScreeningId
        WHERE [ParticipantId] = @ParticipantId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_SessionParticipants', CAST(@ParticipantId AS VARCHAR(50)), 'UPDATE', @PerformedBy,
                'Screening ' + CAST(@ScreeningId AS VARCHAR(20)) + ' linked.');

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_CaseSource_Record ----
   Records a case's identification source. One row per case —
   a second record for the same case throws 50011 (duplicate).
   Missing case -> 50008; unknown/inactive source type -> 50010.
   Does not roll back the caller's work; failures surface as errors. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseSource_Record]
    @CaseId INT,
    @SourceType VARCHAR(30),
    @SourceReferenceId INT = NULL,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewMappingId INT OUTPUT,
    @WasNew BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
            THROW 50008, 'Case not found.', 1;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_CaseSourceTypes]
                       WHERE [SourceTypeCode] = @SourceType AND [IsActive] = 1)
            THROW 50010, 'Invalid case source type.', 1;

        IF EXISTS (SELECT 1 FROM [dbo].[CMS_CaseSourceMapping] WHERE [CaseId] = @CaseId)
            THROW 50011, 'A source is already recorded for this case.', 1;

        INSERT INTO [dbo].[CMS_CaseSourceMapping]
            ([CaseId], [SourceType], [SourceReferenceId], [CreatedBy], [IpAddress])
        VALUES
            (@CaseId, @SourceType, @SourceReferenceId, @CreatedBy, @IpAddress);

        SET @NewMappingId = SCOPE_IDENTITY();
        SET @WasNew = 1;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_CaseSourceMapping', CAST(@NewMappingId AS VARCHAR(50)), 'INSERT', @CreatedBy,
                'Case ' + CAST(@CaseId AS VARCHAR(20)) + ' source ' + @SourceType + '.');

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_CaseSource_GetByCase ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseSource_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.[MappingId], m.[CaseId], m.[SourceType], t.[DisplayName] AS [SourceDisplayName],
           m.[SourceReferenceId], m.[CreatedAt]
    FROM [dbo].[CMS_CaseSourceMapping] m
    INNER JOIN [dbo].[CMS_CaseSourceTypes] t ON t.[SourceTypeCode] = m.[SourceType]
    WHERE m.[CaseId] = @CaseId;
END
GO

/* ---- sp_CMS_CaseSourceType_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseSourceType_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [SourceTypeCode], [DisplayName], [Description], [IsClientSourced], [SortOrder], [IsActive]
    FROM [dbo].[CMS_CaseSourceTypes]
    WHERE [IsActive] = 1
    ORDER BY [SortOrder];
END
GO
