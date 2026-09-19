/* ============================================================
   AKA-CMS — Module 1 remainder seed (15)

   Case source types:
   - Client-sourced codes (IsClientSourced = 1):
       Community / School / HealthFacility / Helpline —
         wireframing logic S1 entry points
         ("Community Entry / School Entry / Health Facility
          Entry / Helpline-Emergency Calls").
       AwarenessSession — Technical Proposal v1, Phase 1 tables
         (AwarenessSessions / SessionParticipants); Phase 3
         "Linked to session".
       Screening — IMHP-CMS_API_Development_Handoff.md §4 Sprint 3
         case-source examples.
   - Handoff-example codes pending client confirmation
     (IsClientSourced = 0):
       WalkIn / Referral — from the handoff's source examples
         ("AwarenessSession, WalkIn, Referral, Helpline,
          Screening etc."); NOT named in any client doc.

   Permission catalog entries 90028-90031 (continuing the
   >= 90000 sequence), granted to the Administrator role with the
   guarded MAX(ID)+1 surrogate pattern.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- Case source types ---- */
MERGE INTO [dbo].[CMS_CaseSourceTypes] AS t
USING (VALUES
    ('Community',        N'Community Entry',       N'S1: Community Entry (wireframing).',                 1, 10),
    ('School',           N'School Entry',          N'S1: School Entry (wireframing).',                    1, 20),
    ('HealthFacility',   N'Health Facility Entry', N'S1: Health Facility Entry (wireframing).',           1, 30),
    ('Helpline',         N'Helpline Call',         N'S1: Helpline-Emergency Calls (wireframing).',        1, 40),
    ('AwarenessSession', N'Awareness Session',     N'Technical Proposal Phase 1/3: session-linked case.',1, 50),
    ('Screening',        N'Screening',             N'Handoff §4 Sprint 3 source example.',                1, 60),
    ('WalkIn',           N'Walk-In',               N'Handoff example only; pending client confirmation.', 0, 70),
    ('Referral',         N'External Referral',     N'Handoff example only; pending client confirmation.', 0, 80)
) AS s ([SourceTypeCode], [DisplayName], [Description], [IsClientSourced], [SortOrder])
ON t.[SourceTypeCode] = s.[SourceTypeCode]
WHEN MATCHED THEN
    UPDATE SET [DisplayName] = s.[DisplayName],
               [Description] = s.[Description],
               [IsClientSourced] = s.[IsClientSourced],
               [SortOrder] = s.[SortOrder],
               [IsActive] = 1
WHEN NOT MATCHED THEN
    INSERT ([SourceTypeCode], [DisplayName], [Description], [IsClientSourced], [SortOrder], [IsActive])
    VALUES (s.[SourceTypeCode], s.[DisplayName], s.[Description], s.[IsClientSourced], s.[SortOrder], 1);
GO

/* ---- Permission catalog entries for awareness sessions & case sources (IDs >= 90000) ---- */
MERGE INTO [dbo].[AllCONTROLLERS] AS t
USING (VALUES
    (90028, 'AwarenessSessions', 'Read'),
    (90029, 'AwarenessSessions', 'Write'),
    (90030, 'CaseSources', 'Read'),
    (90031, 'CaseSources', 'Write')
) AS s ([ID], [CONTROLLERNAME], [ACTION])
ON t.[ID] = s.[ID]
WHEN NOT MATCHED THEN
    INSERT ([ID], [CONTROLLERNAME], [RETURNTYPE], [ATTRIBUTES], [ACTION])
    VALUES (s.[ID], s.[CONTROLLERNAME], NULL, NULL, s.[ACTION]);
GO

/* Administrator role -> awareness/case-source permissions (guarded MAX(ID)+1 surrogate) */
INSERT INTO [dbo].[ROLESACTIONMAPPING]
    ([CONTROLLERID], [ROLEID], [ID], [ACTIVE], [CREATEDBY], [CREATEDDATE], [IPADDRESS])
SELECT s.[ControllerId], 1,
       (SELECT ISNULL(MAX([ID]), 0) FROM [dbo].[ROLESACTIONMAPPING]) + s.[RowNum],
       1, 'seed', SYSUTCDATETIME(), '127.0.0.1'
FROM (VALUES (90028, 1), (90029, 2), (90030, 3), (90031, 4)) AS s ([ControllerId], [RowNum])
WHERE NOT EXISTS (
    SELECT 1 FROM [dbo].[ROLESACTIONMAPPING] m
    WHERE m.[CONTROLLERID] = s.[ControllerId] AND m.[ROLEID] = 1
);
GO
