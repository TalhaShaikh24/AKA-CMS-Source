/* ============================================================
   AKA-CMS — OTP password-reset: verify-only stored procedure

   sp_CMS_PasswordResetOtp_Verify — checks a 4-digit code against
     the database WITHOUT consuming it (the unified forgot-password
     flow: send OTP -> verify OTP -> set new password). Uses the
     same rules as sp_CMS_PasswordResetOtp_Complete: single live
     OTP, expiry, max attempts, account active. A wrong code counts
     an attempt against the newest live OTP, so brute force stays
     bounded across verify + complete. Returns one row (UserId)
     when the code is valid, no rows when it is not.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_PasswordResetOtp_Verify ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_PasswordResetOtp_Verify]
    @UserId INT,
    @OtpHash VARCHAR(128),
    @MaxAttempts INT = 5
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OtpId INT;

    SELECT TOP (1) @OtpId = o.[OtpId]
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

        RETURN;
    END

    SELECT @UserId AS [UserId];
END
GO
