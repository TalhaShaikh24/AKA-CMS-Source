/* ============================================================================
   29_AdUsers.sql
   User Type support + AD directory.
   - sp_CMS_User_GetById / GetAll: return [Type] as UserType.
   - sp_CMS_User_Create: @UserType ('System'|'AD'); ADUSER flag synced;
     credentials row only created when a password hash is supplied
     (AD users authenticate against Active Directory, not a local password).
   - sp_CMS_AdDirectory_GetAll: dummy AD directory with AlreadyAdded flag.
   ============================================================================ */
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
            u.[EMAIL]       AS [Email],
            u.[CREATEDBY]   AS [CreatedBy],
            u.[CREATEDDATE] AS [CreatedDate],
            u.[IPADDRESS]   AS [IpAddress],
            CAST(u.[LOCK] AS BIT)   AS [IsLocked],
            CAST(u.[ACTIVE] AS BIT) AS [IsActive],
            CAST(u.[ADUSER] AS BIT) AS [IsAdUser],
            CAST(u.[ADMIN] AS BIT)  AS [IsAdmin],
            ISNULL(u.[Type], 'System') AS [UserType],
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
            u.[EMAIL]       AS [Email],
            u.[CREATEDBY]   AS [CreatedBy],
            u.[CREATEDDATE] AS [CreatedDate],
            u.[IPADDRESS]   AS [IpAddress],
            CAST(u.[LOCK] AS BIT)   AS [IsLocked],
            CAST(u.[ACTIVE] AS BIT) AS [IsActive],
            CAST(u.[ADUSER] AS BIT) AS [IsAdUser],
            CAST(u.[ADMIN] AS BIT)  AS [IsAdmin],
            ISNULL(u.[Type], 'System') AS [UserType],
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

/* ---- sp_CMS_User_Create (with @UserType) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_User_Create]
    @Username VARCHAR(100),
    @PasswordHash VARCHAR(255) = NULL,
    @CreatedBy INT,
    @Email VARCHAR(255) = NULL,
    @UserType VARCHAR(20) = 'System',
    @NewUserId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @UserType IS NULL OR @UserType NOT IN ('System', 'AD')
        SET @UserType = 'System';

    BEGIN TRY
        BEGIN TRAN;

        SELECT @NewUserId = ISNULL(MAX([USERID]), 0) + 1
        FROM [dbo].[USERS] WITH (UPDLOCK, HOLDLOCK);

        INSERT INTO [dbo].[USERS]
            ([USERID], [USERNAME], [EMAIL], [CREATEDBY], [CREATEDDATE], [IPADDRESS],
             [LOCK], [ACTIVE], [ADUSER], [ADMIN], [Type])
        VALUES
            (@NewUserId, @Username, @Email, CAST(@CreatedBy AS VARCHAR(50)),
             CAST(SYSUTCDATETIME() AS DATE), '0.0.0.0',
             0, 1, CASE WHEN @UserType = 'AD' THEN 1 ELSE 0 END, 0, @UserType);

        -- Local password credentials only for system users (or when a hash is given).
        IF @PasswordHash IS NOT NULL
        BEGIN
            INSERT INTO [dbo].[CMS_UserCredentials] ([UserId], [PasswordHash])
            VALUES (@NewUserId, @PasswordHash);
        END

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('USERS', CAST(@NewUserId AS VARCHAR(50)), 'INSERT', @CreatedBy,
                @Username + ' (' + @UserType + ')');

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_AdDirectory_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_AdDirectory_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  a.[AdUserId]       AS [AdUserId],
            a.[SamAccountName] AS [Username],
            a.[DisplayName]    AS [DisplayName],
            a.[Email]          AS [Email],
            a.[Department]     AS [Department],
            a.[JobTitle]       AS [JobTitle],
            CAST(CASE WHEN EXISTS (
                SELECT 1 FROM [dbo].[USERS] u
                WHERE u.[USERNAME] = a.[SamAccountName]
            ) THEN 1 ELSE 0 END AS BIT) AS [AlreadyAdded]
    FROM [dbo].[CMS_AdDirectoryUsers] a
    WHERE a.[IsEnabled] = 1
    ORDER BY a.[DisplayName];
END
GO
