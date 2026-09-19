/* =============================================================
   24_CMS_RoleSeed.sql — Standard CMS roles + demo users (DEV ONLY)
   - Inserts roles 2-9 into existing [dbo].[ROLES] (guarded).
   - Grants permissions via sp_CMS_Role_AssignPermission (idempotent).
   - Creates one demo user per role; ALL demo users share the dev
     password 'Dev@Admin#2026' (same BCrypt hash as the admin seed).
     CHANGE OR REMOVE THESE USERS BEFORE ANY PRODUCTION DEPLOY.
   - Administrator (role 1) already has all permissions from
     03_CMS_Seed.sql and the per-sprint seeds; not repeated here.
   ============================================================= */
GO
/* Role 2: Supervisor — Supervises case workers; approves case closures; reviews LTFU and crisis escalations. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[ROLES] WHERE [ROLEID] = 2)
    INSERT INTO [dbo].[ROLES] ([ROLEID], [DESCRIPTION], [CREATEDDATE], [CREATEDBY], [IPADDRESS], [ACTIVE])
    VALUES (2, N'Supervisor', SYSUTCDATETIME(), 'seed', '127.0.0.1', 1);
GO
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90001, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90003, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90005, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90007, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90008, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90009, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90010, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90011, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90012, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90013, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90014, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90015, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90016, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90017, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90018, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90019, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90020, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90021, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90022, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90023, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90024, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90025, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90026, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90027, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90028, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90029, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90030, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90031, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90032, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90033, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90034, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90035, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90036, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90037, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90038, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90039, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90040, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90041, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90042, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90043, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90044, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90045, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90046, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90047, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90048, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90049, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90050, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = 90051, @CreatedBy = 'seed', @PerformedBy = 1;
GO
/* Role 3: CaseWorker — Owns assigned cases end-to-end: screening, care plans, referrals, follow-ups. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[ROLES] WHERE [ROLEID] = 3)
    INSERT INTO [dbo].[ROLES] ([ROLEID], [DESCRIPTION], [CREATEDDATE], [CREATEDBY], [IPADDRESS], [ACTIVE])
    VALUES (3, N'CaseWorker', SYSUTCDATETIME(), 'seed', '127.0.0.1', 1);
GO
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90007, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90008, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90009, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90010, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90012, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90013, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90014, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90015, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90016, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90017, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90018, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90019, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90020, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90022, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90024, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90025, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90026, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90027, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90028, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90030, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90032, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90034, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90036, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90038, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90039, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90040, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90043, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90045, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90046, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90047, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90048, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90050, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = 90051, @CreatedBy = 'seed', @PerformedBy = 1;
GO
/* Role 4: FieldWorker — Frontline field staff (mobile app): community identification, awareness sessions, offline screening. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[ROLES] WHERE [ROLEID] = 4)
    INSERT INTO [dbo].[ROLES] ([ROLEID], [DESCRIPTION], [CREATEDDATE], [CREATEDBY], [IPADDRESS], [ACTIVE])
    VALUES (4, N'FieldWorker', SYSUTCDATETIME(), 'seed', '127.0.0.1', 1);
GO
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = 90007, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = 90008, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = 90009, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = 90012, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = 90013, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = 90028, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = 90029, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = 90030, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = 90045, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = 90047, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = 90048, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = 90050, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = 90051, @CreatedBy = 'seed', @PerformedBy = 1;
GO
/* Role 5: Doctor — Psychiatrist: prescribes and manages pharmacological treatment. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[ROLES] WHERE [ROLEID] = 5)
    INSERT INTO [dbo].[ROLES] ([ROLEID], [DESCRIPTION], [CREATEDDATE], [CREATEDBY], [IPADDRESS], [ACTIVE])
    VALUES (5, N'Doctor', SYSUTCDATETIME(), 'seed', '127.0.0.1', 1);
GO
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = 90007, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = 90009, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = 90012, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = 90032, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = 90033, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = 90034, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = 90036, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = 90037, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = 90038, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = 90040, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = 90045, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = 90046, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = 90047, @CreatedBy = 'seed', @PerformedBy = 1;
GO
/* Role 6: Therapist — Psychologist: delivers psychological treatment (therapy) sessions. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[ROLES] WHERE [ROLEID] = 6)
    INSERT INTO [dbo].[ROLES] ([ROLEID], [DESCRIPTION], [CREATEDDATE], [CREATEDBY], [IPADDRESS], [ACTIVE])
    VALUES (6, N'Therapist', SYSUTCDATETIME(), 'seed', '127.0.0.1', 1);
GO
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90007, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90009, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90012, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90018, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90019, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90032, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90033, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90034, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90035, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90038, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90039, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90045, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90046, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90047, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 6, @ControllerActionId = 90048, @CreatedBy = 'seed', @PerformedBy = 1;
GO
/* Role 7: HelplineOperator — Receives helpline calls; logs crises and creates safety plans. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[ROLES] WHERE [ROLEID] = 7)
    INSERT INTO [dbo].[ROLES] ([ROLEID], [DESCRIPTION], [CREATEDDATE], [CREATEDBY], [IPADDRESS], [ACTIVE])
    VALUES (7, N'HelplineOperator', SYSUTCDATETIME(), 'seed', '127.0.0.1', 1);
GO
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 7, @ControllerActionId = 90007, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 7, @ControllerActionId = 90008, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 7, @ControllerActionId = 90009, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 7, @ControllerActionId = 90010, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 7, @ControllerActionId = 90012, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 7, @ControllerActionId = 90022, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 7, @ControllerActionId = 90023, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 7, @ControllerActionId = 90024, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 7, @ControllerActionId = 90025, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 7, @ControllerActionId = 90026, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 7, @ControllerActionId = 90027, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 7, @ControllerActionId = 90045, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 7, @ControllerActionId = 90046, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 7, @ControllerActionId = 90047, @CreatedBy = 'seed', @PerformedBy = 1;
GO
/* Role 8: Pharmacist — Dispenses prescribed medication. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[ROLES] WHERE [ROLEID] = 8)
    INSERT INTO [dbo].[ROLES] ([ROLEID], [DESCRIPTION], [CREATEDDATE], [CREATEDBY], [IPADDRESS], [ACTIVE])
    VALUES (8, N'Pharmacist', SYSUTCDATETIME(), 'seed', '127.0.0.1', 1);
GO
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 8, @ControllerActionId = 90007, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 8, @ControllerActionId = 90009, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 8, @ControllerActionId = 90032, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 8, @ControllerActionId = 90036, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 8, @ControllerActionId = 90037, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 8, @ControllerActionId = 90045, @CreatedBy = 'seed', @PerformedBy = 1;
GO
/* Role 9: Viewer — Read-only access for auditors and management. */
IF NOT EXISTS (SELECT 1 FROM [dbo].[ROLES] WHERE [ROLEID] = 9)
    INSERT INTO [dbo].[ROLES] ([ROLEID], [DESCRIPTION], [CREATEDDATE], [CREATEDBY], [IPADDRESS], [ACTIVE])
    VALUES (9, N'Viewer', SYSUTCDATETIME(), 'seed', '127.0.0.1', 1);
GO
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90001, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90003, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90005, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90007, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90009, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90012, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90014, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90016, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90018, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90020, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90022, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90024, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90026, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90028, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90030, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90032, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90034, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90036, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90038, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90040, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90043, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90045, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90047, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90049, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 9, @ControllerActionId = 90050, @CreatedBy = 'seed', @PerformedBy = 1;
GO
/* Demo user: supervisor -> Supervisor */
IF NOT EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERNAME] = 'supervisor')
    INSERT INTO [dbo].[USERS] ([USERID], [USERNAME], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [LOCK], [ACTIVE], [ADUSER], [ADMIN])
    VALUES (2, 'supervisor', 'seed', CAST(SYSUTCDATETIME() AS DATE), '127.0.0.1', 0, 1, 0, 0);
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_UserCredentials] WHERE [UserId] = 2)
    INSERT INTO [dbo].[CMS_UserCredentials] ([UserId], [PasswordHash])
    VALUES (2, '$2b$11$Ly5kKXTHJ1JBY2sss2QHL.NMtB47BNYGQE8TmatB.jb4KZtLdtE2a');
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[USER_ROLE] WHERE [USERID] = 2 AND [ROLEID] = 2 AND [UCODE] = 0)
    INSERT INTO [dbo].[USER_ROLE] ([USERID], [ROLEID], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [ACTIVE], [ID], [UCODE])
    VALUES (2, 2, 'seed', SYSUTCDATETIME(), '127.0.0.1', 1, 91002, 0);
GO
/* Demo user: caseworker -> CaseWorker */
IF NOT EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERNAME] = 'caseworker')
    INSERT INTO [dbo].[USERS] ([USERID], [USERNAME], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [LOCK], [ACTIVE], [ADUSER], [ADMIN])
    VALUES (3, 'caseworker', 'seed', CAST(SYSUTCDATETIME() AS DATE), '127.0.0.1', 0, 1, 0, 0);
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_UserCredentials] WHERE [UserId] = 3)
    INSERT INTO [dbo].[CMS_UserCredentials] ([UserId], [PasswordHash])
    VALUES (3, '$2b$11$Ly5kKXTHJ1JBY2sss2QHL.NMtB47BNYGQE8TmatB.jb4KZtLdtE2a');
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[USER_ROLE] WHERE [USERID] = 3 AND [ROLEID] = 3 AND [UCODE] = 0)
    INSERT INTO [dbo].[USER_ROLE] ([USERID], [ROLEID], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [ACTIVE], [ID], [UCODE])
    VALUES (3, 3, 'seed', SYSUTCDATETIME(), '127.0.0.1', 1, 91003, 0);
GO
/* Demo user: fieldworker -> FieldWorker */
IF NOT EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERNAME] = 'fieldworker')
    INSERT INTO [dbo].[USERS] ([USERID], [USERNAME], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [LOCK], [ACTIVE], [ADUSER], [ADMIN])
    VALUES (4, 'fieldworker', 'seed', CAST(SYSUTCDATETIME() AS DATE), '127.0.0.1', 0, 1, 0, 0);
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_UserCredentials] WHERE [UserId] = 4)
    INSERT INTO [dbo].[CMS_UserCredentials] ([UserId], [PasswordHash])
    VALUES (4, '$2b$11$Ly5kKXTHJ1JBY2sss2QHL.NMtB47BNYGQE8TmatB.jb4KZtLdtE2a');
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[USER_ROLE] WHERE [USERID] = 4 AND [ROLEID] = 4 AND [UCODE] = 0)
    INSERT INTO [dbo].[USER_ROLE] ([USERID], [ROLEID], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [ACTIVE], [ID], [UCODE])
    VALUES (4, 4, 'seed', SYSUTCDATETIME(), '127.0.0.1', 1, 91004, 0);
GO
/* Demo user: doctor -> Doctor */
IF NOT EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERNAME] = 'doctor')
    INSERT INTO [dbo].[USERS] ([USERID], [USERNAME], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [LOCK], [ACTIVE], [ADUSER], [ADMIN])
    VALUES (5, 'doctor', 'seed', CAST(SYSUTCDATETIME() AS DATE), '127.0.0.1', 0, 1, 0, 0);
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_UserCredentials] WHERE [UserId] = 5)
    INSERT INTO [dbo].[CMS_UserCredentials] ([UserId], [PasswordHash])
    VALUES (5, '$2b$11$Ly5kKXTHJ1JBY2sss2QHL.NMtB47BNYGQE8TmatB.jb4KZtLdtE2a');
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[USER_ROLE] WHERE [USERID] = 5 AND [ROLEID] = 5 AND [UCODE] = 0)
    INSERT INTO [dbo].[USER_ROLE] ([USERID], [ROLEID], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [ACTIVE], [ID], [UCODE])
    VALUES (5, 5, 'seed', SYSUTCDATETIME(), '127.0.0.1', 1, 91005, 0);
GO
/* Demo user: therapist -> Therapist */
IF NOT EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERNAME] = 'therapist')
    INSERT INTO [dbo].[USERS] ([USERID], [USERNAME], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [LOCK], [ACTIVE], [ADUSER], [ADMIN])
    VALUES (6, 'therapist', 'seed', CAST(SYSUTCDATETIME() AS DATE), '127.0.0.1', 0, 1, 0, 0);
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_UserCredentials] WHERE [UserId] = 6)
    INSERT INTO [dbo].[CMS_UserCredentials] ([UserId], [PasswordHash])
    VALUES (6, '$2b$11$Ly5kKXTHJ1JBY2sss2QHL.NMtB47BNYGQE8TmatB.jb4KZtLdtE2a');
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[USER_ROLE] WHERE [USERID] = 6 AND [ROLEID] = 6 AND [UCODE] = 0)
    INSERT INTO [dbo].[USER_ROLE] ([USERID], [ROLEID], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [ACTIVE], [ID], [UCODE])
    VALUES (6, 6, 'seed', SYSUTCDATETIME(), '127.0.0.1', 1, 91006, 0);
GO
/* Demo user: helpline -> HelplineOperator */
IF NOT EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERNAME] = 'helpline')
    INSERT INTO [dbo].[USERS] ([USERID], [USERNAME], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [LOCK], [ACTIVE], [ADUSER], [ADMIN])
    VALUES (7, 'helpline', 'seed', CAST(SYSUTCDATETIME() AS DATE), '127.0.0.1', 0, 1, 0, 0);
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_UserCredentials] WHERE [UserId] = 7)
    INSERT INTO [dbo].[CMS_UserCredentials] ([UserId], [PasswordHash])
    VALUES (7, '$2b$11$Ly5kKXTHJ1JBY2sss2QHL.NMtB47BNYGQE8TmatB.jb4KZtLdtE2a');
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[USER_ROLE] WHERE [USERID] = 7 AND [ROLEID] = 7 AND [UCODE] = 0)
    INSERT INTO [dbo].[USER_ROLE] ([USERID], [ROLEID], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [ACTIVE], [ID], [UCODE])
    VALUES (7, 7, 'seed', SYSUTCDATETIME(), '127.0.0.1', 1, 91007, 0);
GO
/* Demo user: pharmacist -> Pharmacist */
IF NOT EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERNAME] = 'pharmacist')
    INSERT INTO [dbo].[USERS] ([USERID], [USERNAME], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [LOCK], [ACTIVE], [ADUSER], [ADMIN])
    VALUES (8, 'pharmacist', 'seed', CAST(SYSUTCDATETIME() AS DATE), '127.0.0.1', 0, 1, 0, 0);
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_UserCredentials] WHERE [UserId] = 8)
    INSERT INTO [dbo].[CMS_UserCredentials] ([UserId], [PasswordHash])
    VALUES (8, '$2b$11$Ly5kKXTHJ1JBY2sss2QHL.NMtB47BNYGQE8TmatB.jb4KZtLdtE2a');
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[USER_ROLE] WHERE [USERID] = 8 AND [ROLEID] = 8 AND [UCODE] = 0)
    INSERT INTO [dbo].[USER_ROLE] ([USERID], [ROLEID], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [ACTIVE], [ID], [UCODE])
    VALUES (8, 8, 'seed', SYSUTCDATETIME(), '127.0.0.1', 1, 91008, 0);
GO
/* Demo user: viewer -> Viewer */
IF NOT EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERNAME] = 'viewer')
    INSERT INTO [dbo].[USERS] ([USERID], [USERNAME], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [LOCK], [ACTIVE], [ADUSER], [ADMIN])
    VALUES (9, 'viewer', 'seed', CAST(SYSUTCDATETIME() AS DATE), '127.0.0.1', 0, 1, 0, 0);
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_UserCredentials] WHERE [UserId] = 9)
    INSERT INTO [dbo].[CMS_UserCredentials] ([UserId], [PasswordHash])
    VALUES (9, '$2b$11$Ly5kKXTHJ1JBY2sss2QHL.NMtB47BNYGQE8TmatB.jb4KZtLdtE2a');
GO
IF NOT EXISTS (SELECT 1 FROM [dbo].[USER_ROLE] WHERE [USERID] = 9 AND [ROLEID] = 9 AND [UCODE] = 0)
    INSERT INTO [dbo].[USER_ROLE] ([USERID], [ROLEID], [CREATEDBY], [CREATEDDATE], [IPADDRESS], [ACTIVE], [ID], [UCODE])
    VALUES (9, 9, 'seed', SYSUTCDATETIME(), '127.0.0.1', 1, 91009, 0);
GO
