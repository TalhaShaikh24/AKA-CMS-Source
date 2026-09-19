/* ============================================================================
   AKA-CMS — Sprint 8 seed.
   - CMS_SystemSettings: attachment upload limits (provisional,
     IsClientSourced = 0 — the client has not specified limits).
   - Permission catalog entries 90045-90051 (continuing the >= 90000
     sequence), granted to the Administrator role via
     sp_CMS_Role_AssignPermission (never direct INSERT into
     ROLEACTIONMAPPING).
   ============================================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

MERGE INTO [dbo].[CMS_SystemSettings] AS t
USING (VALUES
    ('Attachments.MaxAttachmentBytes', N'10485760',
     N'Maximum attachment file size in bytes (10 MB). Provisional.', 0),
    ('Attachments.AllowedAttachmentTypes', N'pdf,jpg,jpeg,png,doc,docx,xls,xlsx,txt,csv',
     N'Comma-separated lowercase file extensions allowed for uploads. Provisional.', 0)
) AS s ([SettingKey], [SettingValue], [Description], [IsClientSourced])
ON t.[SettingKey] = s.[SettingKey]
WHEN MATCHED THEN
    UPDATE SET [SettingValue] = s.[SettingValue],
               [Description] = s.[Description],
               [IsClientSourced] = s.[IsClientSourced],
               [UpdatedAt] = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT ([SettingKey], [SettingValue], [Description], [IsClientSourced])
    VALUES (s.[SettingKey], s.[SettingValue], s.[Description], s.[IsClientSourced]);
GO

/* ---- Permission catalog entries for notifications / attachments / audit / sync ---- */
MERGE INTO [dbo].[AllCONTROLLERS] AS t
USING (VALUES
    (90045, 'Notifications', 'Read'),
    (90046, 'Notifications', 'Write'),
    (90047, 'Attachments',   'Read'),
    (90048, 'Attachments',   'Write'),
    (90049, 'AuditLogs',     'Read'),
    (90050, 'Sync',          'Read'),
    (90051, 'Sync',          'Write')
) AS s ([ID], [CONTROLLERNAME], [ACTION])
ON t.[ID] = s.[ID]
WHEN NOT MATCHED THEN
    INSERT ([ID], [CONTROLLERNAME], [RETURNTYPE], [ATTRIBUTES], [ACTION])
    VALUES (s.[ID], s.[CONTROLLERNAME], NULL, NULL, s.[ACTION]);
GO

EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90045, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90046, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90047, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90048, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90049, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90050, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90051, @CreatedBy = 'seed', @PerformedBy = 1;
GO
