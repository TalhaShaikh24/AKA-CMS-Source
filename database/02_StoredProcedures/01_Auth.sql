/* ============================================================
   AKA-CMS — Auth stored procedures
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_Auth_GetUserByUsername ----
   Result set 1: user row (+ password hash). Result set 2: role names. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Auth_GetUserByUsername]
    @Username VARCHAR(100)
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
            c.[PasswordHash] AS [PasswordHash]
    FROM [dbo].[USERS] u
    LEFT JOIN [dbo].[CMS_UserCredentials] c ON c.[UserId] = u.[USERID]
    WHERE u.[USERNAME] = @Username;

    SELECT r.[DESCRIPTION]
    FROM [dbo].[USER_ROLE] ur
    INNER JOIN [dbo].[ROLES] r ON r.[ROLEID] = ur.[ROLEID]
    INNER JOIN [dbo].[USERS] u ON u.[USERID] = ur.[USERID]
    WHERE u.[USERNAME] = @Username
      AND ur.[ACTIVE] = 1
      AND r.[ACTIVE] = 1;
END
GO

/* ---- sp_CMS_Auth_GetUserById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Auth_GetUserById]
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
            c.[PasswordHash] AS [PasswordHash]
    FROM [dbo].[USERS] u
    LEFT JOIN [dbo].[CMS_UserCredentials] c ON c.[UserId] = u.[USERID]
    WHERE u.[USERID] = @UserId;

    SELECT r.[DESCRIPTION]
    FROM [dbo].[USER_ROLE] ur
    INNER JOIN [dbo].[ROLES] r ON r.[ROLEID] = ur.[ROLEID]
    WHERE ur.[USERID] = @UserId
      AND ur.[ACTIVE] = 1
      AND r.[ACTIVE] = 1;
END
GO

/* ---- sp_CMS_Auth_GetUserPermissions ----
   Effective permission catalog entries for a user, resolved through
   USER_ROLE -> ROLESACTIONMAPPING -> AllCONTROLLERS (active only). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Auth_GetUserPermissions]
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT ac.[ID] AS [Id],
                    ac.[CONTROLLERNAME] AS [ControllerName],
                    ac.[ACTION] AS [Action]
    FROM [dbo].[USER_ROLE] ur
    INNER JOIN [dbo].[ROLES] r ON r.[ROLEID] = ur.[ROLEID] AND r.[ACTIVE] = 1
    INNER JOIN [dbo].[ROLESACTIONMAPPING] ram ON ram.[ROLEID] = ur.[ROLEID] AND ram.[ACTIVE] = 1
    INNER JOIN [dbo].[AllCONTROLLERS] ac ON ac.[ID] = ram.[CONTROLLERID]
    WHERE ur.[USERID] = @UserId
      AND ur.[ACTIVE] = 1;
END
GO

/* ---- sp_CMS_Auth_GetAllPermissions ----
   Full permission catalog (drives policy registration at startup). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Auth_GetAllPermissions]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [ID] AS [Id],
           [CONTROLLERNAME] AS [ControllerName],
           [ACTION] AS [Action]
    FROM [dbo].[AllCONTROLLERS];
END
GO

/* ---- sp_CMS_Auth_SaveRefreshToken ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Auth_SaveRefreshToken]
    @Token VARCHAR(256),
    @UserId INT,
    @ExpiresAt DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO [dbo].[CMS_RefreshTokens] ([Token], [UserId], [ExpiresAt])
        VALUES (@Token, @UserId, @ExpiresAt);

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_RefreshTokens', CAST(SCOPE_IDENTITY() AS VARCHAR(50)), 'INSERT', @UserId, 'Refresh token issued');

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Auth_GetRefreshToken ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Auth_GetRefreshToken]
    @Token VARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [Id], [Token], [UserId], [ExpiresAt], [CreatedAt], [RevokedAt], [ReplacedByToken]
    FROM [dbo].[CMS_RefreshTokens]
    WHERE [Token] = @Token;
END
GO

/* ---- sp_CMS_Auth_RevokeRefreshToken ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Auth_RevokeRefreshToken]
    @Token VARCHAR(256),
    @ReplacedByToken VARCHAR(256) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE [dbo].[CMS_RefreshTokens]
        SET [RevokedAt] = SYSUTCDATETIME(),
            [ReplacedByToken] = @ReplacedByToken
        WHERE [Token] = @Token
          AND [RevokedAt] IS NULL;

        IF @@ROWCOUNT > 0
        BEGIN
            INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
            SELECT 'CMS_RefreshTokens', CAST([Id] AS VARCHAR(50)), 'UPDATE',
                   [UserId], 'Refresh token revoked'
            FROM [dbo].[CMS_RefreshTokens]
            WHERE [Token] = @Token;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
