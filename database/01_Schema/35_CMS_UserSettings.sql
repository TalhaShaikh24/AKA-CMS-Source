/* ============================================================================
   35_CMS_UserSettings.sql
   Settings page backend: per-user profile extras + notification prefs,
   and global system settings (key-value).
   Idempotent: safe to re-run.
   ============================================================================ */

-- ---------- CMS_UserSettings (one row per USERS.USERID) ----------
IF OBJECT_ID(N'[dbo].[CMS_UserSettings]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_UserSettings] (
        [UserId]            INT NOT NULL,
        [DisplayName]       NVARCHAR(200) NULL,
        [Phone]             VARCHAR(20) NULL,
        [Region]            NVARCHAR(100) NULL,
        [Bio]               NVARCHAR(1000) NULL,
        [EmailAlerts]       BIT NOT NULL CONSTRAINT [DF_CMS_UserSettings_EmailAlerts] DEFAULT (1),
        [SmsReminders]      BIT NOT NULL CONSTRAINT [DF_CMS_UserSettings_SmsReminders] DEFAULT (1),
        [FollowUpDigests]   BIT NOT NULL CONSTRAINT [DF_CMS_UserSettings_FollowUpDigests] DEFAULT (0),
        [CrisisAlerts]      BIT NOT NULL CONSTRAINT [DF_CMS_UserSettings_CrisisAlerts] DEFAULT (1),
        [UpdatedAt]         DATETIME2 NOT NULL CONSTRAINT [DF_CMS_UserSettings_UpdatedAt] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_CMS_UserSettings] PRIMARY KEY CLUSTERED ([UserId])
    );
END
GO

-- ---------- CMS_SystemSettings (global key-value) ----------
IF OBJECT_ID(N'[dbo].[CMS_SystemSettings]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_SystemSettings] (
        [SettingKey]   VARCHAR(100) NOT NULL,
        [SettingValue] NVARCHAR(500) NULL,
        [UpdatedBy]    INT NULL,
        [UpdatedAt]    DATETIME2 NOT NULL CONSTRAINT [DF_CMS_SystemSettings_UpdatedAt] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_CMS_SystemSettings] PRIMARY KEY CLUSTERED ([SettingKey])
    );

    INSERT INTO [dbo].[CMS_SystemSettings] ([SettingKey], [SettingValue])
    VALUES ('DefaultRegion', ''),
           ('SessionTimeout', '30'),
           ('DataRetentionMonths', '24');
END
GO
