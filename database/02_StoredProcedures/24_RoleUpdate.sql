/* ==========================================================================
   CMS Roles — UPDATE description
   ========================================================================== */

CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Role_Update]
    @RoleId INT,
    @Description NVARCHAR(100),
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[ROLES] WHERE [ROLEID] = @RoleId)
            THROW 50008, 'Role not found.', 1;

        UPDATE [dbo].[ROLES]
        SET [DESCRIPTION] = @Description
        WHERE [ROLEID] = @RoleId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('ROLES', CAST(@RoleId AS VARCHAR(50)), 'UPDATE', @PerformedBy, @Description);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
