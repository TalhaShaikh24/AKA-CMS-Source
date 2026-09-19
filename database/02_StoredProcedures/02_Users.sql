/* ============================================================
   AKA-CMS — User management stored procedures
   Write procs run in a transaction and write CMS_AuditLogs.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_User_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_User_GetById]
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  u.[USERID]      AS [UserId],
            u.[USERNAME]    AS [Username],
            u.[CREATEDBY]   AS [CreatedBy],
            u.[CREATEDDATE] AS [CreatedDate],
            u.[IPADDRESS]   AS [IpAddress],
            CAST(u.[LOCK] AS BIT)   AS [IsLocked],
            CAST(u.[ACTIVE] AS BIT) AS [IsActive],
            CAST(u.[ADUSER] AS BIT) AS [IsAdUser],
            CAST(u.[ADMIN] AS BIT)  AS [IsAdmin],
            CAST(NULL AS VARCHAR(255)) AS [PasswordHash]
    FROM [dbo].[USERS] u
    WHERE u.[USERID] = @UserId;

    SELECT r.[DESCRIPTION]
    FROM [dbo].[USER_ROLE] ur
    INNER JOIN [dbo].[ROLES] r ON r.[ROLEID] = ur.[ROLEID]
    WHERE ur.[USERID] = @UserId
      AND ur.[ACTIVE] = 1
      AND r.[ACTIVE] = 1;
END
GO

/* ---- sp_CMS_User_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_User_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  u.[USERID]      AS [UserId],
            u.[USERNAME]    AS [Username],
            u.[CREATEDBY]   AS [CreatedBy],
            u.[CREATEDDATE] AS [CreatedDate],
            u.[IPADDRESS]   AS [IpAddress],
            CAST(u.[LOCK] AS BIT)   AS [IsLocked],
            CAST(u.[ACTIVE] AS BIT) AS [IsActive],
            CAST(u.[ADUSER] AS BIT) AS [IsAdUser],
            CAST(u.[ADMIN] AS BIT)  AS [IsAdmin],
            CAST(NULL AS VARCHAR(255)) AS [PasswordHash]
    FROM [dbo].[USERS] u
    ORDER BY u.[USERNAME];

    SELECT ur.[USERID] AS [UserId],
           r.[DESCRIPTION] AS [RoleName]
    FROM [dbo].[USER_ROLE] ur
    INNER JOIN [dbo].[ROLES] r ON r.[ROLEID] = ur.[ROLEID]
    WHERE ur.[ACTIVE] = 1
      AND r.[ACTIVE] = 1;
END
GO

/* ---- sp_CMS_User_Create ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_User_Create]
    @Username VARCHAR(100),
    @PasswordHash VARCHAR(255),
    @CreatedBy INT,
    @NewUserId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        SELECT @NewUserId = ISNULL(MAX([USERID]), 0) + 1
        FROM [dbo].[USERS] WITH (UPDLOCK, HOLDLOCK);

        INSERT INTO [dbo].[USERS]
            ([USERID], [USERNAME], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [LOCK], [ACTIVE], [ADUSER], [ADMIN])
        VALUES
            (@NewUserId, @Username, CAST(@CreatedBy AS VARCHAR(50)), CAST(SYSUTCDATETIME() AS DATE), '0.0.0.0', 0, 1, 0, 0);

        INSERT INTO [dbo].[CMS_UserCredentials] ([UserId], [PasswordHash])
        VALUES (@NewUserId, @PasswordHash);

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('USERS', CAST(@NewUserId AS VARCHAR(50)), 'INSERT', @CreatedBy, @Username);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_User_Update ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_User_Update]
    @UserId INT,
    @IsActive BIT = NULL,
    @IsLocked BIT = NULL,
    @PasswordHash VARCHAR(255) = NULL,
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE [dbo].[USERS]
        SET [ACTIVE] = ISNULL(@IsActive, [ACTIVE]),
            [LOCK]   = ISNULL(@IsLocked, [LOCK])
        WHERE [USERID] = @UserId;

        IF @PasswordHash IS NOT NULL
        BEGIN
            IF EXISTS (SELECT 1 FROM [dbo].[CMS_UserCredentials] WHERE [UserId] = @UserId)
                UPDATE [dbo].[CMS_UserCredentials]
                SET [PasswordHash] = @PasswordHash, [UpdatedAt] = SYSUTCDATETIME()
                WHERE [UserId] = @UserId;
            ELSE
                INSERT INTO [dbo].[CMS_UserCredentials] ([UserId], [PasswordHash])
                VALUES (@UserId, @PasswordHash);
        END

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy])
        VALUES ('USERS', CAST(@UserId AS VARCHAR(50)), 'UPDATE', @PerformedBy);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_User_AssignRole ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_User_AssignRole]
    @UserId INT,
    @RoleId INT,
    @UnitCode INT = 0,
    @CreatedBy VARCHAR(50),
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[USER_ROLE]
                       WHERE [USERID] = @UserId AND [ROLEID] = @RoleId AND [UCODE] = @UnitCode)
        BEGIN
            DECLARE @NewId INT;
            SELECT @NewId = ISNULL(MAX([ID]), 0) + 1
            FROM [dbo].[USER_ROLE] WITH (UPDLOCK, HOLDLOCK);

            INSERT INTO [dbo].[USER_ROLE]
                ([USERID], [ROLEID], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [ACTIVE], [ID], [UCODE])
            VALUES
                (@UserId, @RoleId, @CreatedBy, SYSUTCDATETIME(), '0.0.0.0', 1, @NewId, @UnitCode);

            INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
            VALUES ('USER_ROLE', CAST(@UserId AS VARCHAR(50)) + '/' + CAST(@RoleId AS VARCHAR(50)),
                    'INSERT', @PerformedBy, 'Role assigned');
        END

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_User_RemoveRole ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_User_RemoveRole]
    @UserId INT,
    @RoleId INT,
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DELETE FROM [dbo].[USER_ROLE]
        WHERE [USERID] = @UserId AND [ROLEID] = @RoleId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('USER_ROLE', CAST(@UserId AS VARCHAR(50)) + '/' + CAST(@RoleId AS VARCHAR(50)),
                'DELETE', @PerformedBy, 'Role removed');

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
