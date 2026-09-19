-- ============================================================
-- AKA-CMS Sprint 0-1 : Role create stored procedure
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_CMS_Role_Create
    @Description NVARCHAR(100),
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @NewRoleId INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @NewRoleId = ISNULL(MAX(ROLEID), 0) + 1
        FROM dbo.ROLES WITH (UPDLOCK, HOLDLOCK);

        INSERT INTO dbo.ROLES (ROLEID, DESCRIPTION, CREATEDDATE, CREATEDBY, IPADDRESS, ACTIVE)
        VALUES (@NewRoleId, @Description, SYSUTCDATETIME(), CAST(@PerformedBy AS VARCHAR(50)), '127.0.0.1', 1);

        INSERT INTO dbo.CMS_AuditLogs (TableName, RecordId, Action, PerformedBy, Details)
        VALUES ('ROLES', CAST(@NewRoleId AS VARCHAR(50)), 'INSERT', @PerformedBy, @Description);

        COMMIT TRANSACTION;
        SELECT @NewRoleId AS RoleId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
