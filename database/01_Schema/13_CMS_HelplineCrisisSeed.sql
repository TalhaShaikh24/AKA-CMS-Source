/* ============================================================
   AKA-CMS — Sprint 4 seed (13)

   Crisis types are taken from the AUTHORITATIVE client doc:
   AKU_-_Technical_Proposal_V1.pdf, "Phase C: Crisis Detection
   (Critical Path)" — Trigger Conditions:
     Suicidal intent / Severe self-harm risk / Psychosis /
     Panic attack / Substance crisis.
   OTH (Other Acute Crisis) is added as an extensible catch-all;
   it is NOT from the proposal — documented here so the client
   can confirm or remove it.

   Plus permission catalog entries 90022-90027 granted to the
   Administrator role (continuing the guarded MAX(ID)+1 pattern).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- Crisis types (Technical Proposal v1, Phase C) ---- */
MERGE INTO [dbo].[CMS_CrisisTypes] AS t
USING (VALUES
    ('SUI', N'Suicidal Intent',        'CRITICAL', N'Trigger: Suicidal intent (Proposal Phase C).',            10),
    ('SHM', N'Severe Self-Harm Risk',  'CRITICAL', N'Trigger: Severe self-harm risk (Proposal Phase C).',      20),
    ('PSY', N'Psychosis',              'CRITICAL', N'Trigger: Psychosis (Proposal Phase C).',                  30),
    ('PAN', N'Panic Attack',           'HIGH',     N'Trigger: Panic attack / severe anxiety (Proposal Phase C).', 40),
    ('SUB', N'Substance Crisis',       'HIGH',     N'Trigger: Substance crisis (Proposal Phase C).',            50),
    ('OTH', N'Other Acute Crisis',     'HIGH',     N'Extensible catch-all; pending client confirmation.',       60)
) AS s ([CrisisTypeCode], [DisplayName], [DefaultSeverity], [Description], [SortOrder])
ON t.[CrisisTypeCode] = s.[CrisisTypeCode]
WHEN MATCHED THEN
    UPDATE SET [DisplayName] = s.[DisplayName],
               [DefaultSeverity] = s.[DefaultSeverity],
               [Description] = s.[Description],
               [SortOrder] = s.[SortOrder],
               [IsActive] = 1
WHEN NOT MATCHED THEN
    INSERT ([CrisisTypeCode], [DisplayName], [DefaultSeverity], [Description], [SortOrder], [IsActive])
    VALUES (s.[CrisisTypeCode], s.[DisplayName], s.[DefaultSeverity], s.[Description], s.[SortOrder], 1);
GO

/* ---- Permission catalog entries for helpline & crisis (IDs >= 90000) ---- */
MERGE INTO [dbo].[AllCONTROLLERS] AS t
USING (VALUES
    (90022, 'Helpline', 'Read'),
    (90023, 'Helpline', 'Write'),
    (90024, 'Crisis', 'Read'),
    (90025, 'Crisis', 'Write'),
    (90026, 'SafetyPlans', 'Read'),
    (90027, 'SafetyPlans', 'Write')
) AS s ([ID], [CONTROLLERNAME], [ACTION])
ON t.[ID] = s.[ID]
WHEN NOT MATCHED THEN
    INSERT ([ID], [CONTROLLERNAME], [RETURNTYPE], [ATTRIBUTES], [ACTION])
    VALUES (s.[ID], s.[CONTROLLERNAME], NULL, NULL, s.[ACTION]);
GO

/* Administrator role -> helpline/crisis permissions (guarded MAX(ID)+1 surrogate) */
INSERT INTO [dbo].[ROLESACTIONMAPPING]
    ([CONTROLLERID], [ROLEID], [ID], [ACTIVE], [CREATEDBY], [CREATEDDATE], [IPADDRESS])
SELECT s.[ControllerId], 1,
       (SELECT ISNULL(MAX([ID]), 0) FROM [dbo].[ROLESACTIONMAPPING]) + s.[RowNum],
       1, 'seed', SYSUTCDATETIME(), '127.0.0.1'
FROM (VALUES (90022, 1), (90023, 2), (90024, 3), (90025, 4),
             (90026, 5), (90027, 6)) AS s ([ControllerId], [RowNum])
WHERE NOT EXISTS (
    SELECT 1 FROM [dbo].[ROLESACTIONMAPPING] m
    WHERE m.[CONTROLLERID] = s.[ControllerId] AND m.[ROLEID] = 1
);
GO
