/* ============================================================
   AKA-CMS — Patient identity & MR resolution stored procedures
   Write procs run in a transaction and write CMS_AuditLogs.

   Custom THROW numbers:
     50001 - no active MR block configured for the unit
     50002 - MR block exhausted for the unit
     50003 - mapping not found
     50004 - only dummy mappings can be remapped
     50005 - row-version mismatch (optimistic concurrency)
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_CommunityMember_Create ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CommunityMember_Create]
    @FullName NVARCHAR(200),
    @FatherName NVARCHAR(200) = NULL,
    @Gender VARCHAR(10) = NULL,
    @DateOfBirth DATE = NULL,
    @Cnic VARCHAR(15) = NULL,
    @Phone VARCHAR(20) = NULL,
    @Address NVARCHAR(500) = NULL,
    @UnionCouncilCode VARCHAR(20) = NULL,
    @VillageCode VARCHAR(20) = NULL,
    @MrNo VARCHAR(20) = NULL,
    @Age INT = NULL,
    @RegionCouncil NVARCHAR(100) = NULL,
    @LocalCouncil NVARCHAR(100) = NULL,
    @Village NVARCHAR(100) = NULL,
    @JkAttend NVARCHAR(100) = NULL,
    @EmploymentEducation NVARCHAR(200) = NULL,
    @MaritalStatus VARCHAR(30) = NULL,
    @NumberOfChildren INT = NULL,
    @LanguagesSpoken NVARCHAR(200) = NULL,
    @HealthInsurance VARCHAR(50) = NULL,
    @GpUsualCare NVARCHAR(200) = NULL,
    @PriorMhTreatment VARCHAR(50) = NULL,
    @ConnectedToMhCare VARCHAR(50) = NULL,
    @CareProviderName NVARCHAR(200) = NULL,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewMemberId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO [dbo].[CMS_CommunityMembers]
            ([MrNo], [FullName], [FatherName], [Gender], [DateOfBirth], [Cnic], [Phone],
             [Address], [UnionCouncilCode], [VillageCode], [Age], [RegionCouncil],
             [LocalCouncil], [Village], [JkAttend], [EmploymentEducation], [MaritalStatus],
             [NumberOfChildren], [LanguagesSpoken], [HealthInsurance], [GpUsualCare],
             [PriorMhTreatment], [ConnectedToMhCare], [CareProviderName],
             [IsActive], [CreatedBy], [IpAddress])
        VALUES
            (@MrNo, @FullName, @FatherName, @Gender, @DateOfBirth, @Cnic, @Phone,
             @Address, @UnionCouncilCode, @VillageCode, @Age, @RegionCouncil,
             @LocalCouncil, @Village, @JkAttend, @EmploymentEducation, @MaritalStatus,
             @NumberOfChildren, @LanguagesSpoken, @HealthInsurance, @GpUsualCare,
             @PriorMhTreatment, @ConnectedToMhCare, @CareProviderName,
             1, @CreatedBy, @IpAddress);

        SET @NewMemberId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_CommunityMembers', CAST(@NewMemberId AS VARCHAR(50)), 'INSERT', @CreatedBy, @FullName);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_CommunityMember_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CommunityMember_GetById]
    @MemberId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  [MemberId],
            [MrNo],
            [FullName],
            [FatherName],
            [Gender],
            [DateOfBirth],
            [Cnic],
            [Phone],
            [Address],
            [UnionCouncilCode],
            [VillageCode],
            [Age],
            [RegionCouncil],
            [LocalCouncil],
            [Village],
            [JkAttend],
            [EmploymentEducation],
            [MaritalStatus],
            [NumberOfChildren],
            [LanguagesSpoken],
            [HealthInsurance],
            [GpUsualCare],
            [PriorMhTreatment],
            [ConnectedToMhCare],
            [CareProviderName],
            [IsActive],
            [RowVersion]
    FROM [dbo].[CMS_CommunityMembers]
    WHERE [MemberId] = @MemberId;
END
GO

/* ---- sp_CMS_CommunityMember_Search ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CommunityMember_Search]
    @SearchTerm VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  'CMS' AS [Source],
            cm.[MemberId] AS [MemberId],
            cm.[MrNo] AS [MrNo],
            cm.[FullName] AS [FullName],
            cm.[Gender] AS [Gender],
            cm.[Phone] AS [Phone],
            CAST(NULL AS INT) AS [UnitCode],
            CAST(NULL AS DATETIME) AS [LastEncounterAt]
    FROM [dbo].[CMS_CommunityMembers] cm
    WHERE cm.[IsActive] = 1
      AND (@SearchTerm IS NULL OR @SearchTerm = ''
           OR cm.[FullName] LIKE '%' + @SearchTerm + '%'
           OR cm.[MrNo] = @SearchTerm
           OR cm.[Cnic] = @SearchTerm
           OR cm.[Phone] LIKE '%' + @SearchTerm + '%')

    UNION ALL

    SELECT  'HIS' AS [Source],
            CAST(NULL AS INT) AS [MemberId],
            e.[MRNO] AS [MrNo],
            CAST(NULL AS NVARCHAR(200)) AS [FullName],
            CAST(NULL AS VARCHAR(10)) AS [Gender],
            CAST(NULL AS VARCHAR(20)) AS [Phone],
            e.[UnitCode] AS [UnitCode],
            e.[LastEncounterAt] AS [LastEncounterAt]
    FROM (
        SELECT [MRNO], MAX([UCODE]) AS [UnitCode], MAX([CREATEDDATE]) AS [LastEncounterAt]
        FROM [dbo].[PAT_ENCTR]
        GROUP BY [MRNO]
    ) e
    WHERE (@SearchTerm IS NULL OR @SearchTerm = '' OR e.[MRNO] LIKE '%' + @SearchTerm + '%')
      AND NOT EXISTS (
            SELECT 1 FROM [dbo].[CMS_HisMrMappings] m
            WHERE m.[MrNo] = e.[MRNO] AND m.[IsActive] = 1
      )
    ORDER BY [MrNo];
END
GO

/* ---- sp_CMS_HisMrMapping_ResolveOrCreate ----
   Yes/No MR logic: a known MR at any HIS encounter (or an existing
   non-dummy mapping) resolves as-is; otherwise a dummy MR is issued
   from the facility's reserved block. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_HisMrMapping_ResolveOrCreate]
    @MrNo VARCHAR(20) = NULL,
    @UnitCode INT,
    @CommunityMemberId INT = NULL,
    @CreatedBy INT,
    @IpAddress VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MappingId INT;
    DECLARE @WasCreated BIT = 0;
    DECLARE @EffectiveMrNo VARCHAR(20);
    DECLARE @IsDummy BIT = 0;

    BEGIN TRY
        BEGIN TRAN;

        IF @MrNo IS NOT NULL AND @MrNo <> ''
           AND (EXISTS (SELECT 1 FROM [dbo].[PAT_ENCTR] WHERE [MRNO] = @MrNo)
                OR EXISTS (SELECT 1 FROM [dbo].[CMS_HisMrMappings]
                           WHERE [MrNo] = @MrNo AND [IsDummy] = 0 AND [IsActive] = 1))
        BEGIN
            SELECT @MappingId = [MappingId]
            FROM [dbo].[CMS_HisMrMappings]
            WHERE [MrNo] = @MrNo AND [UnitCode] = @UnitCode AND [IsDummy] = 0 AND [IsActive] = 1;

            IF @MappingId IS NULL
            BEGIN
                INSERT INTO [dbo].[CMS_HisMrMappings]
                    ([CommunityMemberId], [MrNo], [IsDummy], [UnitCode], [IsActive], [CreatedBy], [IpAddress])
                VALUES
                    (@CommunityMemberId, @MrNo, 0, @UnitCode, 1, @CreatedBy, @IpAddress);

                SET @MappingId = SCOPE_IDENTITY();
                SET @WasCreated = 1;

                INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
                VALUES ('CMS_HisMrMappings', CAST(@MappingId AS VARCHAR(50)), 'INSERT', @CreatedBy, @MrNo);
            END

            SET @EffectiveMrNo = @MrNo;
            SET @IsDummy = 0;
        END
        ELSE
        BEGIN
            DECLARE @Prefix VARCHAR(10), @Next INT, @BlockEnd INT;

            SELECT @Prefix = [MrPrefix], @Next = [NextSequence], @BlockEnd = [BlockEnd]
            FROM [dbo].[CMS_FacilityMrBlocks] WITH (UPDLOCK, HOLDLOCK)
            WHERE [UnitCode] = @UnitCode AND [IsActive] = 1;

            IF @@ROWCOUNT = 0
                THROW 50001, 'No active MR block configured for the unit.', 1;

            IF @Next > @BlockEnd
                THROW 50002, 'MR block exhausted for the unit.', 1;

            SET @EffectiveMrNo = @Prefix + '-' + RIGHT('000000' + CAST(@Next AS VARCHAR(10)), 6);

            UPDATE [dbo].[CMS_FacilityMrBlocks]
            SET [NextSequence] = @Next + 1
            WHERE [UnitCode] = @UnitCode AND [IsActive] = 1;

            INSERT INTO [dbo].[CMS_HisMrMappings]
                ([CommunityMemberId], [MrNo], [IsDummy], [UnitCode], [IsActive], [CreatedBy], [IpAddress])
            VALUES
                (@CommunityMemberId, @EffectiveMrNo, 1, @UnitCode, 1, @CreatedBy, @IpAddress);

            SET @MappingId = SCOPE_IDENTITY();
            SET @WasCreated = 1;
            SET @IsDummy = 1;

            INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
            VALUES ('CMS_HisMrMappings', CAST(@MappingId AS VARCHAR(50)), 'INSERT', @CreatedBy, @EffectiveMrNo);
        END

        IF @CommunityMemberId IS NOT NULL
            UPDATE [dbo].[CMS_CommunityMembers]
            SET [MrNo] = @EffectiveMrNo
            WHERE [MemberId] = @CommunityMemberId AND [MrNo] IS NULL;

        COMMIT TRAN;

        SELECT  @MappingId AS [MappingId],
                @CommunityMemberId AS [CommunityMemberId],
                @EffectiveMrNo AS [MrNo],
                @IsDummy AS [IsDummy],
                @UnitCode AS [UnitCode],
                CAST(NULL AS VARCHAR(20)) AS [ResolvedMrNo],
                @WasCreated AS [WasCreated],
                m.[RowVersion] AS [RowVersion]
        FROM [dbo].[CMS_HisMrMappings] m
        WHERE m.[MappingId] = @MappingId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_HisMrMapping_RemapToRealMr ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_HisMrMapping_RemapToRealMr]
    @MappingId INT,
    @RealMrNo VARCHAR(20),
    @RowVersion BINARY(8),
    @PerformedBy INT,
    @IpAddress VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @CurrentRowVersion BINARY(8);
        DECLARE @IsDummy BIT;
        DECLARE @CommunityMemberId INT;

        SELECT @CurrentRowVersion = [RowVersion],
               @IsDummy = [IsDummy],
               @CommunityMemberId = [CommunityMemberId]
        FROM [dbo].[CMS_HisMrMappings] WITH (UPDLOCK)
        WHERE [MappingId] = @MappingId AND [IsActive] = 1;

        IF @@ROWCOUNT = 0
            THROW 50003, 'MR mapping not found.', 1;

        IF @IsDummy = 0
            THROW 50004, 'Only dummy mappings can be remapped to a real MR.', 1;

        IF @CurrentRowVersion <> @RowVersion
            THROW 50005, 'The mapping was modified by another user. Reload and try again.', 1;

        UPDATE [dbo].[CMS_HisMrMappings]
        SET [ResolvedMrNo] = @RealMrNo
        WHERE [MappingId] = @MappingId;

        IF @CommunityMemberId IS NOT NULL
            UPDATE [dbo].[CMS_CommunityMembers]
            SET [MrNo] = @RealMrNo
            WHERE [MemberId] = @CommunityMemberId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_HisMrMappings', CAST(@MappingId AS VARCHAR(50)), 'UPDATE', @PerformedBy, @RealMrNo);

        COMMIT TRAN;

        SELECT  [MappingId],
                [CommunityMemberId],
                [MrNo],
                [IsDummy],
                [UnitCode],
                [ResolvedMrNo],
                [RowVersion]
        FROM [dbo].[CMS_HisMrMappings]
        WHERE [MappingId] = @MappingId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_FacilityMrBlock_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_FacilityMrBlock_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  [FacilityMrBlockId],
            [UnitCode],
            [MrPrefix],
            [BlockStart],
            [BlockEnd],
            [NextSequence],
            [IsPlaceholder],
            [IsActive],
            [RowVersion]
    FROM [dbo].[CMS_FacilityMrBlocks]
    ORDER BY [UnitCode];
END
GO

/* ---- sp_CMS_FacilityMrBlock_Upsert ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_FacilityMrBlock_Upsert]
    @UnitCode INT,
    @MrPrefix VARCHAR(10),
    @BlockStart INT,
    @BlockEnd INT,
    @IsActive BIT,
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF EXISTS (SELECT 1 FROM [dbo].[CMS_FacilityMrBlocks] WHERE [UnitCode] = @UnitCode)
        BEGIN
            UPDATE [dbo].[CMS_FacilityMrBlocks]
            SET [MrPrefix] = @MrPrefix,
                [BlockStart] = @BlockStart,
                [BlockEnd] = @BlockEnd,
                [NextSequence] = CASE WHEN [NextSequence] < @BlockStart THEN @BlockStart ELSE [NextSequence] END,
                [IsPlaceholder] = 0,
                [IsActive] = @IsActive
            WHERE [UnitCode] = @UnitCode;
        END
        ELSE
        BEGIN
            INSERT INTO [dbo].[CMS_FacilityMrBlocks]
                ([UnitCode], [MrPrefix], [BlockStart], [BlockEnd], [NextSequence], [IsPlaceholder], [IsActive], [CreatedBy])
            VALUES
                (@UnitCode, @MrPrefix, @BlockStart, @BlockEnd, @BlockStart, 0, @IsActive, @PerformedBy);
        END

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_FacilityMrBlocks', CAST(@UnitCode AS VARCHAR(50)), 'UPSERT', @PerformedBy, @MrPrefix);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
