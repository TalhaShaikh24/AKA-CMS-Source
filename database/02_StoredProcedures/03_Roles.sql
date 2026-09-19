/* ============================================================
   AKA-CMS — Role management stored procedures
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_Role_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Role_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [ROLEID]      AS [RoleId],
           [DESCRIPTION] AS [Description],
           [CREATEDDATE] AS [CreatedDate],
           [CREATEDBY]   AS [CreatedBy],
           [IPADDRESS]   AS [IpAddress],
           CAST([ACTIVE] AS BIT) AS [IsActive]
    FROM [dbo].[ROLES]
    ORDER BY [DESCRIPTION];
END
GO

/* ---- sp_CMS_Role_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Role_GetById]
    @RoleId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [ROLEID]      AS [RoleId],
           [DESCRIPTION] AS [Description],
           [CREATEDDATE] AS [CreatedDate],
           [CREATEDBY]   AS [CreatedBy],
           [IPADDRESS]   AS [IpAddress],
           CAST([ACTIVE] AS BIT) AS [IsActive]
    FROM [dbo].[ROLES]
    WHERE [ROLEID] = @RoleId;
END
GO

/* ---- sp_CMS_Role_GetPermissions ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Role_GetPermissions]
    @RoleId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ac.[ID] AS [Id],
           ac.[CONTROLLERNAME] AS [ControllerName],
           ac.[ACTION] AS [Action]
    FROM [dbo].[ROLESACTIONMAPPING] ram
    INNER JOIN [dbo].[AllCONTROLLERS] ac ON ac.[ID] = ram.[CONTROLLERID]
    WHERE ram.[ROLEID] = @RoleId
      AND ram.[ACTIVE] = 1
    ORDER BY ac.[CONTROLLERNAME], ac.[ACTION];
END
GO

/* ---- sp_CMS_Role_AssignPermission ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Role_AssignPermission]
    @RoleId INT,
    @ControllerActionId INT,
    @CreatedBy VARCHAR(50),
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[ROLESACTIONMAPPING]
                       WHERE [ROLEID] = @RoleId AND [CONTROLLERID] = @ControllerActionId)
        BEGIN
            DECLARE @NewId INT;
            SELECT @NewId = ISNULL(MAX([ID]), 0) + 1
            FROM [dbo].[ROLESACTIONMAPPING] WITH (UPDLOCK, HOLDLOCK);

            INSERT INTO [dbo].[ROLESACTIONMAPPING]
                ([CONTROLLERID], [ROLEID], [ID], [ACTIVE], [CREATEDBY], [CREATEDDATE], [IPADDRESS])
            VALUES
                (@ControllerActionId, @RoleId, @NewId, 1, @CreatedBy, SYSUTCDATETIME(), '0.0.0.0');

            INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
            VALUES ('ROLESACTIONMAPPING', CAST(@RoleId AS VARCHAR(50)) + '/' + CAST(@ControllerActionId AS VARCHAR(50)),
                    'INSERT', @PerformedBy, 'Permission granted to role');
        END

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Role_RemovePermission ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Role_RemovePermission]
    @RoleId INT,
    @ControllerActionId INT,
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DELETE FROM [dbo].[ROLESACTIONMAPPING]
        WHERE [ROLEID] = @RoleId AND [CONTROLLERID] = @ControllerActionId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('ROLESACTIONMAPPING', CAST(@RoleId AS VARCHAR(50)) + '/' + CAST(@ControllerActionId AS VARCHAR(50)),
                'DELETE', @PerformedBy, 'Permission revoked from role');

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
