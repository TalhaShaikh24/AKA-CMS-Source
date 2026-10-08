/* ============================================================
   AKA-CMS — OTP password-reset stored procedures
   (mobile design: Forget Pass -> OTP -> Reset Pass)

   sp_CMS_PasswordResetOtp_Create  — stores a new OTP hash, drops any
     older unused OTPs for the same user.
   sp_CMS_PasswordResetOtp_Complete — verifies the OTP (single-use,
     expiry, max attempts) and atomically applies the new password,
     consumes the OTP and revokes all refresh tokens. Returns the
     user row on success, no rows on failure.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_PasswordResetOtp_Create ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_PasswordResetOtp_Create]
    @UserId INT,
    @OtpHash VARCHAR(128),
    @ExpiresAt DATETIME2,
    @IpAddress VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DELETE FROM [dbo].[CMS_PasswordResetOtps]
        WHERE [UserId] = @UserId
          AND [UsedAt] IS NULL;

        INSERT INTO [dbo].[CMS_PasswordResetOtps]
            ([UserId], [OtpHash], [ExpiresAt], [IpAddress])
        VALUES
            (@UserId, @OtpHash, @ExpiresAt, @IpAddress);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_PasswordResetOtp_Complete ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_PasswordResetOtp_Complete]
    @UserId INT,
    @OtpHash VARCHAR(128),
    @PasswordHash VARCHAR(255),
    @MaxAttempts INT = 5
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @OtpId INT, @Attempts INT;

        SELECT TOP (1) @OtpId = o.[OtpId], @Attempts = o.[AttemptCount]
        FROM [dbo].[CMS_PasswordResetOtps] o
        INNER JOIN [dbo].[USERS] u ON u.[USERID] = o.[UserId]
        WHERE o.[UserId] = @UserId
          AND o.[OtpHash] = @OtpHash
          AND o.[UsedAt] IS NULL
          AND o.[ExpiresAt] > SYSUTCDATETIME()
          AND o.[AttemptCount] < @MaxAttempts
          AND u.[ACTIVE] = 1
          AND u.[LOCK] = 0
        ORDER BY o.[OtpId] DESC;

        IF @OtpId IS NULL
        BEGIN
            /* Wrong/expired code: count the attempt against the newest
               live OTP so brute force is bounded. */
            UPDATE TOP (1) [dbo].[CMS_PasswordResetOtps]
            SET [AttemptCount] = [AttemptCount] + 1
            WHERE [UserId] = @UserId
              AND [UsedAt] IS NULL
              AND [ExpiresAt] > SYSUTCDATETIME()
              AND [AttemptCount] < @MaxAttempts;

            ROLLBACK TRANSACTION;
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM [dbo].[CMS_UserCredentials] WHERE [UserId] = @UserId)
            UPDATE [dbo].[CMS_UserCredentials]
            SET [PasswordHash] = @PasswordHash, [UpdatedAt] = SYSUTCDATETIME()
            WHERE [UserId] = @UserId;
        ELSE
            INSERT INTO [dbo].[CMS_UserCredentials] ([UserId], [PasswordHash])
            VALUES (@UserId, @PasswordHash);

        UPDATE [dbo].[CMS_PasswordResetOtps]
        SET [UsedAt] = SYSUTCDATETIME()
        WHERE [OtpId] = @OtpId;

        UPDATE [dbo].[CMS_RefreshTokens]
        SET [RevokedAt] = SYSUTCDATETIME()
        WHERE [UserId] = @UserId
          AND [RevokedAt] IS NULL;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_UserCredentials', CAST(@UserId AS VARCHAR(50)), 'UPDATE', @UserId,
                'Password changed via OTP; sessions revoked');

        COMMIT TRANSACTION;

        SELECT u.[USERID]   AS [UserId],
               u.[USERNAME] AS [Username],
               u.[EMAIL]    AS [Email]
        FROM [dbo].[USERS] u
        WHERE u.[USERID] = @UserId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
