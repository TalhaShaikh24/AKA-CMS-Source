/* ============================================================================
   27_Settings.sql
   Settings page stored procedures.
   ============================================================================ */

/* ---- sp_CMS_UserSettings_Get: profile + notification prefs for a user ---- */
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
            ISNULL(s.[CrisisAlerts], 1) AS [CrisisAlerts]
    FROM [dbo].[USERS] u
    LEFT JOIN [dbo].[CMS_UserSettings] s ON s.[UserId] = u.[USERID]
    WHERE u.[USERID] = @UserId;
END
GO

/* ---- sp_CMS_UserSettings_SaveProfile ---- */
-- NOTE: QUOTED_IDENTIFIER must be ON at CREATE time (USERS has filtered index UX_USERS_EMAIL).
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_UserSettings_SaveProfile]
    @UserId INT,
    @DisplayName NVARCHAR(200) = NULL,
    @Phone VARCHAR(20) = NULL,
    @Region NVARCHAR(100) = NULL,
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

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_UserSettings_SaveNotifications ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_UserSettings_SaveNotifications]
    @UserId INT,
    @EmailAlerts BIT,
    @SmsReminders BIT,
    @FollowUpDigests BIT,
    @CrisisAlerts BIT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM [dbo].[CMS_UserSettings] WHERE [UserId] = @UserId)
        UPDATE [dbo].[CMS_UserSettings]
        SET [EmailAlerts] = @EmailAlerts,
            [SmsReminders] = @SmsReminders,
            [FollowUpDigests] = @FollowUpDigests,
            [CrisisAlerts] = @CrisisAlerts,
            [UpdatedAt] = SYSUTCDATETIME()
        WHERE [UserId] = @UserId;
    ELSE
        INSERT INTO [dbo].[CMS_UserSettings]
            ([UserId], [EmailAlerts], [SmsReminders], [FollowUpDigests], [CrisisAlerts])
        VALUES (@UserId, @EmailAlerts, @SmsReminders, @FollowUpDigests, @CrisisAlerts);
END
GO

/* ---- sp_CMS_SystemSettings_Get ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_SystemSettings_Get]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [SettingKey], [SettingValue]
    FROM [dbo].[CMS_SystemSettings];
END
GO

/* ---- sp_CMS_SystemSettings_Save ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_SystemSettings_Save]
    @SettingKey VARCHAR(100),
    @SettingValue NVARCHAR(500) = NULL,
    @UpdatedBy INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM [dbo].[CMS_SystemSettings] WHERE [SettingKey] = @SettingKey)
        UPDATE [dbo].[CMS_SystemSettings]
        SET [SettingValue] = @SettingValue,
            [UpdatedBy] = @UpdatedBy,
            [UpdatedAt] = SYSUTCDATETIME()
        WHERE [SettingKey] = @SettingKey;
    ELSE
        INSERT INTO [dbo].[CMS_SystemSettings] ([SettingKey], [SettingValue], [UpdatedBy])
        VALUES (@SettingKey, @SettingValue, @UpdatedBy);
END
GO
