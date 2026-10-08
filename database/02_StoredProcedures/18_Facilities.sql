/* ============================================================
   AKA-CMS — Facility directory stored procedures
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

/* ---- sp_CMS_Facility_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Facility_GetAll]
    @IncludeInactive BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  [FacilityId],
            [FacilityCode],
            [FacilityName],
            [FacilityType],
            [Region],
            [Address],
            [Phone],
            [IsActive],
            [RowVersion]
    FROM [dbo].[CMS_Facilities]
    WHERE ([IsActive] = 1 OR @IncludeInactive = 1)
    ORDER BY [FacilityName];
END
GO

/* ---- sp_CMS_Facility_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Facility_GetById]
    @FacilityId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  [FacilityId],
            [FacilityCode],
            [FacilityName],
            [FacilityType],
            [Region],
            [Address],
            [Phone],
            [IsActive],
            [RowVersion]
    FROM [dbo].[CMS_Facilities]
    WHERE [FacilityId] = @FacilityId;
END
GO

/* ---- sp_CMS_Facility_Create ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Facility_Create]
    @FacilityCode VARCHAR(20),
    @FacilityName NVARCHAR(200),
    @FacilityType VARCHAR(50) = NULL,
    @Region NVARCHAR(100) = NULL,
    @Address NVARCHAR(500) = NULL,
    @Phone VARCHAR(20) = NULL,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewFacilityId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF EXISTS (SELECT 1 FROM [dbo].[CMS_Facilities] WHERE [FacilityCode] = @FacilityCode)
            THROW 50011, 'A facility with this code already exists.', 1;

        INSERT INTO [dbo].[CMS_Facilities]
            ([FacilityCode], [FacilityName], [FacilityType], [Region], [Address], [Phone],
             [IsActive], [CreatedBy], [IpAddress])
        VALUES
            (@FacilityCode, @FacilityName, @FacilityType, @Region, @Address, @Phone,
             1, @CreatedBy, @IpAddress);

        SET @NewFacilityId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Facilities', CAST(@NewFacilityId AS VARCHAR(50)), 'INSERT', @CreatedBy, @FacilityName);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Facility_Update ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Facility_Update]
    @FacilityId INT,
    @FacilityName NVARCHAR(200),
    @FacilityType VARCHAR(50) = NULL,
    @Region NVARCHAR(100) = NULL,
    @Address NVARCHAR(500) = NULL,
    @Phone VARCHAR(20) = NULL,
    @IsActive BIT = 1,
    @RowVersion ROWVERSION,
    @PerformedBy INT,
    @IpAddress VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Facilities]
                       WHERE [FacilityId] = @FacilityId AND [RowVersion] = @RowVersion)
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Facilities] WHERE [FacilityId] = @FacilityId)
                THROW 50008, 'Facility not found.', 1;
            THROW 50005, 'The facility was modified by another user.', 1;
        END

        UPDATE [dbo].[CMS_Facilities]
        SET [FacilityName] = @FacilityName,
            [FacilityType] = @FacilityType,
            [Region] = @Region,
            [Address] = @Address,
            [Phone] = @Phone,
            [IsActive] = @IsActive
        WHERE [FacilityId] = @FacilityId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Facilities', CAST(@FacilityId AS VARCHAR(50)), 'UPDATE', @PerformedBy, @FacilityName);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
