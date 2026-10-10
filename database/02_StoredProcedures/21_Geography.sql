/* ============================================================
   AKA-CMS — Geography master-data stored procedures
   (Regions, Local Councils, Villages).
   Write procs run in a transaction and write CMS_AuditLogs.

   Custom THROW numbers (project-wide):
     50005 - row-version mismatch (optimistic concurrency)
     50008 - entity not found
     50011 - duplicate/conflict
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ================= REGIONS ================= */

/* ---- sp_CMS_Region_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Region_GetAll]
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  [RegionId],
            [RegionName],
            [IsActive],
            [RowVersion]
    FROM [dbo].[CMS_Regions]
    WHERE ([IsActive] = 1 OR @IncludeInactive = 1)
    ORDER BY [RegionName];
END
GO

/* ---- sp_CMS_Region_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Region_GetById]
    @RegionId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  [RegionId],
            [RegionName],
            [IsActive],
            [RowVersion]
    FROM [dbo].[CMS_Regions]
    WHERE [RegionId] = @RegionId;
END
GO

/* ---- sp_CMS_Region_Create ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Region_Create]
    @RegionName NVARCHAR(100),
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewRegionId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF EXISTS (SELECT 1 FROM [dbo].[CMS_Regions] WHERE [RegionName] = @RegionName)
            THROW 50011, 'A region with this name already exists.', 1;

        INSERT INTO [dbo].[CMS_Regions]
            ([RegionName], [CreatedBy], [IpAddress])
        VALUES
            (@RegionName, @CreatedBy, @IpAddress);

        SET @NewRegionId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Regions', CAST(@NewRegionId AS VARCHAR(50)), 'INSERT', @CreatedBy, @RegionName);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Region_Update ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Region_Update]
    @RegionId INT,
    @RegionName NVARCHAR(100),
    @IsActive BIT,
    @RowVersion ROWVERSION,
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Regions] WHERE [RegionId] = @RegionId)
            THROW 50008, 'Region not found.', 1;

        IF EXISTS (SELECT 1 FROM [dbo].[CMS_Regions] WHERE [RegionName] = @RegionName AND [RegionId] <> @RegionId)
            THROW 50011, 'Another region with this name already exists.', 1;

        UPDATE [dbo].[CMS_Regions]
        SET [RegionName] = @RegionName,
            [IsActive] = @IsActive
        WHERE [RegionId] = @RegionId
          AND [RowVersion] = @RowVersion;

        IF @@ROWCOUNT = 0
            THROW 50005, 'This record was modified by another user. Please reload and try again.', 1;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Regions', CAST(@RegionId AS VARCHAR(50)), 'UPDATE', @PerformedBy, @RegionName);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ================= LOCAL COUNCILS ================= */

/* ---- sp_CMS_LocalCouncil_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_LocalCouncil_GetAll]
    @RegionId INT = NULL,
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  c.[CouncilId],
            c.[RegionId],
            r.[RegionName],
            c.[CouncilName],
            c.[IsActive],
            c.[RowVersion]
    FROM [dbo].[CMS_LocalCouncils] AS c
    LEFT JOIN [dbo].[CMS_Regions] AS r ON r.[RegionId] = c.[RegionId]
    WHERE (c.[IsActive] = 1 OR @IncludeInactive = 1)
      AND (@RegionId IS NULL OR c.[RegionId] = @RegionId OR c.[RegionId] IS NULL)
    ORDER BY c.[CouncilName];
END
GO

/* ---- sp_CMS_LocalCouncil_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_LocalCouncil_GetById]
    @CouncilId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  c.[CouncilId],
            c.[RegionId],
            r.[RegionName],
            c.[CouncilName],
            c.[IsActive],
            c.[RowVersion]
    FROM [dbo].[CMS_LocalCouncils] AS c
    LEFT JOIN [dbo].[CMS_Regions] AS r ON r.[RegionId] = c.[RegionId]
    WHERE c.[CouncilId] = @CouncilId;
END
GO

/* ---- sp_CMS_LocalCouncil_Create ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_LocalCouncil_Create]
    @RegionId INT = NULL,
    @CouncilName NVARCHAR(100),
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewCouncilId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF EXISTS (SELECT 1 FROM [dbo].[CMS_LocalCouncils] WHERE [CouncilName] = @CouncilName)
            THROW 50011, 'A local council with this name already exists.', 1;

        IF @RegionId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Regions] WHERE [RegionId] = @RegionId)
            THROW 50008, 'Region not found.', 1;

        INSERT INTO [dbo].[CMS_LocalCouncils]
            ([RegionId], [CouncilName], [CreatedBy], [IpAddress])
        VALUES
            (@RegionId, @CouncilName, @CreatedBy, @IpAddress);

        SET @NewCouncilId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_LocalCouncils', CAST(@NewCouncilId AS VARCHAR(50)), 'INSERT', @CreatedBy, @CouncilName);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_LocalCouncil_Update ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_LocalCouncil_Update]
    @CouncilId INT,
    @RegionId INT = NULL,
    @CouncilName NVARCHAR(100),
    @IsActive BIT,
    @RowVersion ROWVERSION,
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_LocalCouncils] WHERE [CouncilId] = @CouncilId)
            THROW 50008, 'Local council not found.', 1;

        IF EXISTS (SELECT 1 FROM [dbo].[CMS_LocalCouncils] WHERE [CouncilName] = @CouncilName AND [CouncilId] <> @CouncilId)
            THROW 50011, 'Another local council with this name already exists.', 1;

        UPDATE [dbo].[CMS_LocalCouncils]
        SET [RegionId] = @RegionId,
            [CouncilName] = @CouncilName,
            [IsActive] = @IsActive
        WHERE [CouncilId] = @CouncilId
          AND [RowVersion] = @RowVersion;

        IF @@ROWCOUNT = 0
            THROW 50005, 'This record was modified by another user. Please reload and try again.', 1;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_LocalCouncils', CAST(@CouncilId AS VARCHAR(50)), 'UPDATE', @PerformedBy, @CouncilName);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ================= VILLAGES ================= */

/* ---- sp_CMS_Village_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Village_GetAll]
    @CouncilId INT = NULL,
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  v.[VillageId],
            v.[CouncilId],
            c.[CouncilName],
            v.[VillageName],
            v.[IsActive],
            v.[RowVersion]
    FROM [dbo].[CMS_Villages] AS v
    LEFT JOIN [dbo].[CMS_LocalCouncils] AS c ON c.[CouncilId] = v.[CouncilId]
    WHERE (v.[IsActive] = 1 OR @IncludeInactive = 1)
      AND (@CouncilId IS NULL OR v.[CouncilId] = @CouncilId OR v.[CouncilId] IS NULL)
    ORDER BY v.[VillageName];
END
GO

/* ---- sp_CMS_Village_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Village_GetById]
    @VillageId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  v.[VillageId],
            v.[CouncilId],
            c.[CouncilName],
            v.[VillageName],
            v.[IsActive],
            v.[RowVersion]
    FROM [dbo].[CMS_Villages] AS v
    LEFT JOIN [dbo].[CMS_LocalCouncils] AS c ON c.[CouncilId] = v.[CouncilId]
    WHERE v.[VillageId] = @VillageId;
END
GO

/* ---- sp_CMS_Village_Create ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Village_Create]
    @CouncilId INT = NULL,
    @VillageName NVARCHAR(100),
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewVillageId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF EXISTS (SELECT 1 FROM [dbo].[CMS_Villages] WHERE [VillageName] = @VillageName)
            THROW 50011, 'A village with this name already exists.', 1;

        IF @CouncilId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [dbo].[CMS_LocalCouncils] WHERE [CouncilId] = @CouncilId)
            THROW 50008, 'Local council not found.', 1;

        INSERT INTO [dbo].[CMS_Villages]
            ([CouncilId], [VillageName], [CreatedBy], [IpAddress])
        VALUES
            (@CouncilId, @VillageName, @CreatedBy, @IpAddress);

        SET @NewVillageId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Villages', CAST(@NewVillageId AS VARCHAR(50)), 'INSERT', @CreatedBy, @VillageName);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Village_Update ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Village_Update]
    @VillageId INT,
    @CouncilId INT = NULL,
    @VillageName NVARCHAR(100),
    @IsActive BIT,
    @RowVersion ROWVERSION,
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Villages] WHERE [VillageId] = @VillageId)
            THROW 50008, 'Village not found.', 1;

        IF EXISTS (SELECT 1 FROM [dbo].[CMS_Villages] WHERE [VillageName] = @VillageName AND [VillageId] <> @VillageId)
            THROW 50011, 'Another village with this name already exists.', 1;

        UPDATE [dbo].[CMS_Villages]
        SET [CouncilId] = @CouncilId,
            [VillageName] = @VillageName,
            [IsActive] = @IsActive
        WHERE [VillageId] = @VillageId
          AND [RowVersion] = @RowVersion;

        IF @@ROWCOUNT = 0
            THROW 50005, 'This record was modified by another user. Please reload and try again.', 1;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Villages', CAST(@VillageId AS VARCHAR(50)), 'UPDATE', @PerformedBy, @VillageName);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
