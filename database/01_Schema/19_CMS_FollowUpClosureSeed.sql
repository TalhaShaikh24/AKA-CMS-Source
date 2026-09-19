/* ============================================================================
   AKA-CMS — Sprint 7 seed.
   - CMS_SystemSettings: risk-based follow-up frequencies + LTFU threshold.
     All values are provisional (IsClientSourced = 0) pending client
     confirmation. Frequency defaults follow the wireframing risk paths
     (high-risk frequent contact / moderate structured / low routine);
     the LTFU threshold default (1 missed follow-up) follows S33b.
   - Permission catalog entries 90038-90044 (continuing the >= 90000
     sequence), granted to the Administrator role with the guarded
     MAX(ID)+1 surrogate pattern inside sp_CMS_Role_AssignPermission.
   ============================================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

MERGE INTO [dbo].[CMS_SystemSettings] AS t
USING (VALUES
    ('FollowUp.FrequencyDays.High',     N'7',  N'Follow-up due after N days for High priority cases. Provisional.', 0),
    ('FollowUp.FrequencyDays.Moderate', N'14', N'Follow-up due after N days for Moderate priority cases. Provisional.', 0),
    ('FollowUp.FrequencyDays.Low',      N'30', N'Follow-up due after N days for Low priority cases. Provisional.', 0),
    ('Ltfu.MissedFollowUpThreshold',    N'1',  N'Consecutive missed follow-ups before LTFU is declared (wireframing S33b). Provisional.', 0)
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

/* ---- Permission catalog entries for follow-up / closure / supervision ---- */
MERGE INTO [dbo].[AllCONTROLLERS] AS t
USING (VALUES
    (90038, 'FollowUps',    'Read'),
    (90039, 'FollowUps',    'Write'),
    (90040, 'CaseClosure',  'Read'),
    (90041, 'CaseClosure',  'Write'),
    (90042, 'CaseClosure',  'Approve'),
    (90043, 'Supervision',  'Read'),
    (90044, 'Supervision',  'Write')
) AS s ([ID], [CONTROLLERNAME], [ACTION])
ON t.[ID] = s.[ID]
WHEN NOT MATCHED THEN
    INSERT ([ID], [CONTROLLERNAME], [RETURNTYPE], [ATTRIBUTES], [ACTION])
    VALUES (s.[ID], s.[CONTROLLERNAME], NULL, NULL, s.[ACTION]);
GO

/* Administrator role -> follow-up / closure / supervision permissions.
   Granted through sp_CMS_Role_AssignPermission (idempotent) because this
   local dev database has a corrupt catalog name-index on
   ROLEACTIONMAPPING — ad-hoc INSERT ... dbo.ROLEACTIONMAPPING fails with
   Msg 208, while the existing proc resolves the table through its bound
   object-id. Local-environment quirk only; the client's real database
   is unaffected. */
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90038, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90039, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90040, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90041, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90042, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90043, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90044, @CreatedBy = 'seed', @PerformedBy = 1;
GO
