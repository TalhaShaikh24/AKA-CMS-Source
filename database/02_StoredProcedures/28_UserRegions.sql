/* ============================================================================
   28_UserRegions.sql
   Multi-region support for users.
   ============================================================================ */

/* ---- sp_CMS_UserSettings_Get: now includes Regions (comma-separated) ---- */
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_UserSettings_Get]
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  u.[USERID] AS [UserId],
            u.[USERNAME] AS [Username],
            u.[EMAIL] AS [Email],
            s.[DisplayName],
            s.[Phone],
            s.[Region],
            s.[Bio],
            ISNULL(s.[EmailAlerts], 1) AS [EmailAlerts],
            ISNULL(s.[SmsReminders], 1) AS [SmsReminders],
            ISNULL(s.[FollowUpDigests], 0) AS [FollowUpDigests],
            ISNULL(s.[CrisisAlerts], 1) AS [CrisisAlerts],
            STUFF((
                SELECT ',' + ur.[RegionName]
                FROM [dbo].[CMS_UserRegions] ur
                WHERE ur.[UserId] = u.[USERID]
                ORDER BY ur.[RegionName]
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS [Regions]
    FROM [dbo].[USERS] u
    LEFT JOIN [dbo].[CMS_UserSettings] s ON s.[UserId] = u.[USERID]
    WHERE u.[USERID] = @UserId;
END
GO

/* ---- sp_CMS_UserRegions_Save: replace user's region list ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_UserRegions_Save]
    @UserId INT,
    @Regions NVARCHAR(MAX) = NULL  -- comma-separated region names
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM [dbo].[CMS_UserRegions] WHERE [UserId] = @UserId;

    IF @Regions IS NOT NULL AND LTRIM(RTRIM(@Regions)) <> ''
    BEGIN
        INSERT INTO [dbo].[CMS_UserRegions] ([UserId], [RegionName])
        SELECT DISTINCT @UserId, LTRIM(RTRIM([value]))
        FROM STRING_SPLIT(@Regions, ',')
        WHERE LTRIM(RTRIM([value])) <> '';
    END
END
GO

/* ---- sp_CMS_UserSettings_SaveProfile: multi-region via @Regions ---- */
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_UserSettings_SaveProfile]
    @UserId INT,
    @DisplayName NVARCHAR(200) = NULL,
    @Phone VARCHAR(20) = NULL,
    @Region NVARCHAR(100) = NULL,       -- legacy single value (kept for compat)
    @Regions NVARCHAR(MAX) = NULL,      -- comma-separated multi-region
    @Bio NVARCHAR(1000) = NULL,
    @Email VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET QUOTED_IDENTIFIER ON;

    BEGIN TRY
        BEGIN TRAN;

        IF @Email IS NOT NULL
            UPDATE [dbo].[USERS] SET [EMAIL] = @Email WHERE [USERID] = @UserId;

        IF EXISTS (SELECT 1 FROM [dbo].[CMS_UserSettings] WHERE [UserId] = @UserId)
            UPDATE [dbo].[CMS_UserSettings]
            SET [DisplayName] = @DisplayName,
                [Phone] = @Phone,
                [Region] = @Region,
                [Bio] = @Bio,
                [UpdatedAt] = SYSUTCDATETIME()
            WHERE [UserId] = @UserId;
        ELSE
            INSERT INTO [dbo].[CMS_UserSettings] ([UserId], [DisplayName], [Phone], [Region], [Bio])
            VALUES (@UserId, @DisplayName, @Phone, @Region, @Bio);

        -- Sync multi-region table.
        DELETE FROM [dbo].[CMS_UserRegions] WHERE [UserId] = @UserId;
        IF @Regions IS NOT NULL AND LTRIM(RTRIM(@Regions)) <> ''
        BEGIN
            INSERT INTO [dbo].[CMS_UserRegions] ([UserId], [RegionName])
            SELECT DISTINCT @UserId, LTRIM(RTRIM([value]))
            FROM STRING_SPLIT(@Regions, ',')
            WHERE LTRIM(RTRIM([value])) <> '';
        END

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
