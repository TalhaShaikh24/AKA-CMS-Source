/* ============================================================
   AKA-CMS — seed data (03)
   Inserts only; safe to re-run (guarded by NOT EXISTS).
   Dev admin: username 'admin', password set during provisioning.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* CMS permission catalog in AllCONTROLLERS (IDs reserved >= 90000) */
MERGE INTO [dbo].[AllCONTROLLERS] AS t
USING (VALUES
    (90001, 'Users', 'Read'),
    (90002, 'Users', 'Write'),
    (90003, 'Roles', 'Read'),
    (90004, 'Roles', 'Write'),
    (90005, 'Permissions', 'Read'),
    (90006, 'Permissions', 'Write')
) AS s ([ID], [CONTROLLERNAME], [ACTION])
ON t.[ID] = s.[ID]
WHEN NOT MATCHED THEN
    INSERT ([ID], [CONTROLLERNAME], [RETURNTYPE], [ATTRIBUTES], [ACTION])
    VALUES (s.[ID], s.[CONTROLLERNAME], NULL, NULL, s.[ACTION]);
GO

/* Administrator role */
IF NOT EXISTS (SELECT 1 FROM [dbo].[ROLES] WHERE [ROLEID] = 1)
    INSERT INTO [dbo].[ROLES] ([ROLEID], [DESCRIPTION], [CREATEDDATE], [CREATEDBY], [IPADDRESS], [ACTIVE])
    VALUES (1, 'Administrator', SYSUTCDATETIME(), 'seed', '127.0.0.1', 1);
GO

/* Dev admin user */
IF NOT EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERNAME] = 'admin')
    INSERT INTO [dbo].[USERS] ([USERID], [USERNAME], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [LOCK], [ACTIVE], [ADUSER], [ADMIN])
    VALUES (1, 'admin', 'seed', CAST(SYSUTCDATETIME() AS DATE), '127.0.0.1', 0, 1, 0, 1);
GO

/* Dev admin credentials (BCrypt hash of the provisioned dev password) */
IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_UserCredentials] WHERE [UserId] = 1)
    INSERT INTO [dbo].[CMS_UserCredentials] ([UserId], [PasswordHash])
    VALUES (1, '$2b$11$Ly5kKXTHJ1JBY2sss2QHL.NMtB47BNYGQE8TmatB.jb4KZtLdtE2a');
GO

/* Admin user -> Administrator role */
IF NOT EXISTS (SELECT 1 FROM [dbo].[USER_ROLE] WHERE [USERID] = 1 AND [ROLEID] = 1 AND [UCODE] = 0)
    INSERT INTO [dbo].[USER_ROLE] ([USERID], [ROLEID], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [ACTIVE], [ID], [UCODE])
    VALUES (1, 1, 'seed', SYSUTCDATETIME(), '127.0.0.1', 1, 90001, 0);
GO

/* Administrator role -> all CMS permissions */
MERGE INTO [dbo].[ROLESACTIONMAPPING] AS t
USING (VALUES (90001),(90002),(90003),(90004),(90005),(90006)) AS s ([ID])
ON t.[ID] = s.[ID]
WHEN NOT MATCHED THEN
    INSERT ([CONTROLLERID], [ROLEID], [ID], [ACTIVE], [CREATEDBY], [CREATEDDATE], [IPADDRESS])
    VALUES (s.[ID], 1, s.[ID], 1, 'seed', SYSUTCDATETIME(), '127.0.0.1');
GO
