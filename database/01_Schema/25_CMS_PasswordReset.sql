/* ============================================================
   AKA-CMS — Password reset (25)
   - Adds nullable EMAIL column to the existing CO-HIS USERS table
     (additive only; no existing data is touched).
   - New CMS_PasswordResets table for single-use, expiring reset tokens.
     Only the SHA-256 hash of a token is stored — the raw token is
     emailed to the user and never persisted.
   Safe to re-run (guarded by COL_LENGTH / OBJECT_ID checks).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- USERS.EMAIL (new nullable column on the existing table) ---- */
IF COL_LENGTH(N'[dbo].[USERS]', N'EMAIL') IS NULL
BEGIN
    ALTER TABLE [dbo].[USERS]
        ADD [EMAIL] VARCHAR(255) NULL;
END
GO

/* ---- Unique e-mail per user (NULLs excluded so existing rows stay valid) ---- */
IF NOT EXISTS (SELECT 1 FROM [sys].[indexes] WHERE [name] = N'UX_USERS_EMAIL' AND [object_id] = OBJECT_ID(N'[dbo].[USERS]'))
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX [UX_USERS_EMAIL]
        ON [dbo].[USERS] ([EMAIL])
        WHERE [EMAIL] IS NOT NULL;
END
GO

/* ---- CMS_PasswordResets ---- */
IF OBJECT_ID(N'[dbo].[CMS_PasswordResets]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_PasswordResets](
        [Id] INT IDENTITY(1,1) NOT NULL,
        [UserId] INT NOT NULL,
        [TokenHash] VARCHAR(128) NOT NULL,
        [ExpiresAt] DATETIME2 NOT NULL,
        [UsedAt] DATETIME2 NULL,
        [CreatedAt] DATETIME2 NOT NULL CONSTRAINT [DF_CMS_PasswordResets_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [RequestIp] VARCHAR(64) NULL,
        CONSTRAINT [PK_CMS_PasswordResets] PRIMARY KEY CLUSTERED ([Id] ASC),
        CONSTRAINT [FK_CMS_PasswordResets_USERS] FOREIGN KEY ([UserId]) REFERENCES [dbo].[USERS] ([USERID])
    );

    CREATE UNIQUE NONCLUSTERED INDEX [UX_CMS_PasswordResets_TokenHash]
        ON [dbo].[CMS_PasswordResets] ([TokenHash]);
END
GO

/* ---- Demo seed users: assign e-mail addresses so the forgot-password
        flow is testable out of the box (only where still NULL). ---- */
UPDATE [dbo].[USERS] SET [EMAIL] = 'admin@aka-cms.local'         WHERE [USERNAME] = 'admin'        AND [EMAIL] IS NULL;
GO
UPDATE [dbo].[USERS] SET [EMAIL] = 'supervisor@aka-cms.local'    WHERE [USERNAME] = 'supervisor'   AND [EMAIL] IS NULL;
GO
UPDATE [dbo].[USERS] SET [EMAIL] = 'caseworker@aka-cms.local'    WHERE [USERNAME] = 'caseworker'   AND [EMAIL] IS NULL;
GO
UPDATE [dbo].[USERS] SET [EMAIL] = 'fieldworker@aka-cms.local'   WHERE [USERNAME] = 'fieldworker'  AND [EMAIL] IS NULL;
GO
UPDATE [dbo].[USERS] SET [EMAIL] = 'doctor@aka-cms.local'        WHERE [USERNAME] = 'doctor'       AND [EMAIL] IS NULL;
GO
UPDATE [dbo].[USERS] SET [EMAIL] = 'therapist@aka-cms.local'     WHERE [USERNAME] = 'therapist'    AND [EMAIL] IS NULL;
GO
UPDATE [dbo].[USERS] SET [EMAIL] = 'helpline@aka-cms.local'      WHERE [USERNAME] = 'helpline'     AND [EMAIL] IS NULL;
GO
UPDATE [dbo].[USERS] SET [EMAIL] = 'pharmacist@aka-cms.local'    WHERE [USERNAME] = 'pharmacist'   AND [EMAIL] IS NULL;
GO
UPDATE [dbo].[USERS] SET [EMAIL] = 'viewer@aka-cms.local'        WHERE [USERNAME] = 'viewer'       AND [EMAIL] IS NULL;
GO
