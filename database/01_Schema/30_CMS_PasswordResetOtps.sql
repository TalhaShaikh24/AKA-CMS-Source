/* ============================================================
   AKA-CMS — CMS_PasswordResetOtps table
   One-time passcodes for the OTP password-reset flow
   (mobile design: Forget Pass -> OTP -> Reset Pass).
   Additive and safe to re-run.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[dbo].[CMS_PasswordResetOtps]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_PasswordResetOtps](
        [OtpId] INT IDENTITY(1,1) NOT NULL,
        [UserId] INT NOT NULL,
        [OtpHash] VARCHAR(128) NOT NULL,
        [ExpiresAt] DATETIME2 NOT NULL,
        [AttemptCount] INT NOT NULL CONSTRAINT [DF_CMS_PasswordResetOtps_AttemptCount] DEFAULT (0),
        [UsedAt] DATETIME2 NULL,
        [CreatedAt] DATETIME2 NOT NULL CONSTRAINT [DF_CMS_PasswordResetOtps_CreatedAt] DEFAULT (SYSUTCDATETIME()),
        [IpAddress] VARCHAR(50) NULL,
        CONSTRAINT [PK_CMS_PasswordResetOtps] PRIMARY KEY CLUSTERED ([OtpId] ASC),
        CONSTRAINT [FK_CMS_PasswordResetOtps_USERS] FOREIGN KEY ([UserId])
            REFERENCES [dbo].[USERS] ([USERID])
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_PasswordResetOtps_User]
        ON [dbo].[CMS_PasswordResetOtps] ([UserId] ASC);
END
GO
