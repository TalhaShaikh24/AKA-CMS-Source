/* ============================================================
   AKA-CMS - Sprint 4 seed data (09)
   Screening tools (PHQ-9, GAD-7) with standard scoring bands,
   plus permission catalog entries 90012 Screenings:Read and
   90013 Screenings:Write granted to the Administrator role.

   PHQ-9 bands (standard): 0-4 Minimal, 5-9 Mild, 10-14 Moderate,
   15-19 Moderately severe, 20-27 Severe.
   GAD-7 bands (standard): 0-4 Minimal, 5-9 Mild, 10-14 Moderate,
   15-21 Severe.
   DASS-21 bands below are reference ranges on the WORST-SUBSCALE
   metric (0-21); the submit SP computes each subscale against its
   own published cutoffs and takes the worst band as the overall
   RiskLevel, so the persisted band always matches the max subscale
   severity.
   SBQ-R bands: 3-6 below threshold (Minimal), 7-8 at/above threshold
   (Moderate), 9-18 high risk (Severe).
   C-SSRS bands are a display reference on the 0-6 item sum; the
   actual risk is derived per-item by the submit SP (ideation <
   intent/plan < behavior).
   Safe to re-run (guarded by MERGE / NOT EXISTS).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- Screening tools ---- */
MERGE INTO [dbo].[CMS_ScreeningTools] AS t
USING (VALUES
    ('PHQ9', 'Patient Health Questionnaire-9',
     'Depression screening: 9 items scored 0-3, total 0-27. Item 10 (functional difficulty) is not scored.',
     9, 3, 0, 27),
    ('GAD7', 'Generalized Anxiety Disorder-7',
     'Anxiety screening: 7 items scored 0-3, total 0-21. Item 8 (functional difficulty) is not scored.',
     7, 3, 0, 21),
    ('DASS21', 'Depression Anxiety Stress Scales-21',
     'DASS-21: 21 items scored 0-3. Three subscales (Depression items 3,5,10,13,16,17,21; Anxiety items 2,4,7,9,15,19,20; Stress items 1,6,8,11,12,14,18), each 0-21. RawScore is the 0-63 total; RiskLevel is the worst subscale band per published DASS cutoffs; subscale scores are persisted in SubscaleScoresJson.',
     21, 3, 0, 63),
    ('SBQR', 'Suicide Behaviors Questionnaire-Revised',
     'SBQ-R: 4 items with per-item ranges (item1: 1-4, item2: 1-5, item3: 1-3, item4: 0-6), total 3-18. Published risk thresholds: >=7 (general population), >=8 (clinical).',
     4, 6, 3, 18),
    ('CSSRS', 'Columbia-Suicide Severity Rating Scale (Screener)',
     'C-SSRS screener: 6 yes/no items (0/1) — wish to be dead, suicidal thoughts, method considered, some intent, specific plan/intent, suicidal behavior. Risk is derived from the highest endorsed tier (ideation < intent/plan < behavior) per published screener logic; RawScore is the 0-6 item sum for display.',
     6, 1, 0, 6)
) AS s ([ToolCode], [ToolName], [Description], [ItemCount], [MaxItemScore], [MinScore], [MaxScore])
ON t.[ToolCode] = s.[ToolCode]
WHEN MATCHED THEN
    UPDATE SET [ToolName] = s.[ToolName], [Description] = s.[Description],
               [ItemCount] = s.[ItemCount], [MaxItemScore] = s.[MaxItemScore],
               [MinScore] = s.[MinScore], [MaxScore] = s.[MaxScore], [IsActive] = 1
WHEN NOT MATCHED THEN
    INSERT ([ToolCode], [ToolName], [Description], [ItemCount], [MaxItemScore], [MinScore], [MaxScore], [IsActive])
    VALUES (s.[ToolCode], s.[ToolName], s.[Description], s.[ItemCount], s.[MaxItemScore], s.[MinScore], s.[MaxScore], 1);
GO

/* ---- Risk bands ---- */
MERGE INTO [dbo].[CMS_ScreeningRiskBands] AS t
USING (VALUES
    ('PHQ9', 'MINIMAL',   'Minimal',           0,  4, 10),
    ('PHQ9', 'MILD',      'Mild',              5,  9, 20),
    ('PHQ9', 'MODERATE',  'Moderate',         10, 14, 30),
    ('PHQ9', 'MOD_SEVERE','Moderately severe',15, 19, 40),
    ('PHQ9', 'SEVERE',    'Severe',           20, 27, 50),
    ('GAD7', 'MINIMAL',   'Minimal',           0,  4, 10),
    ('GAD7', 'MILD',      'Mild',              5,  9, 20),
    ('GAD7', 'MODERATE',  'Moderate',         10, 14, 30),
    ('GAD7', 'SEVERE',    'Severe',           15, 21, 40),
    ('DASS21', 'MINIMAL',   'Minimal',           0,  4, 10),
    ('DASS21', 'MILD',      'Mild',              5,  6, 20),
    ('DASS21', 'MODERATE',  'Moderate',          7, 10, 30),
    ('DASS21', 'MOD_SEVERE','Moderately severe',11, 13, 40),
    ('DASS21', 'SEVERE',    'Severe',           14, 21, 50),
    ('SBQR', 'MINIMAL',   'Minimal (below risk threshold)', 3, 6, 10),
    ('SBQR', 'MODERATE',  'Moderate (at/above risk threshold)', 7, 8, 30),
    ('SBQR', 'SEVERE',    'Severe (high risk)', 9, 18, 50),
    ('CSSRS', 'MINIMAL',   'Minimal (no endorsement)', 0, 0, 10),
    ('CSSRS', 'MILD',      'Mild (ideation only)', 1, 2, 20),
    ('CSSRS', 'MODERATE',  'Moderate (method considered)', 3, 3, 30),
    ('CSSRS', 'MOD_SEVERE','Moderately severe (intent/plan)', 4, 4, 40),
    ('CSSRS', 'SEVERE',    'Severe (behavior)', 5, 6, 50)
) AS s ([ToolCode], [BandCode], [BandName], [MinScore], [MaxScore], [SortOrder])
ON t.[ToolCode] = s.[ToolCode] AND t.[BandCode] = s.[BandCode]
WHEN MATCHED THEN
    UPDATE SET [BandName] = s.[BandName], [MinScore] = s.[MinScore],
               [MaxScore] = s.[MaxScore], [SortOrder] = s.[SortOrder], [IsActive] = 1
WHEN NOT MATCHED THEN
    INSERT ([ToolCode], [BandCode], [BandName], [MinScore], [MaxScore], [SortOrder], [IsActive])
    VALUES (s.[ToolCode], s.[BandCode], s.[BandName], s.[MinScore], s.[MaxScore], s.[SortOrder], 1);
GO

/* ---- Permission catalog entries for screenings (IDs >= 90000) ---- */
MERGE INTO [dbo].[AllCONTROLLERS] AS t
USING (VALUES
    (90012, 'Screenings', 'Read'),
    (90013, 'Screenings', 'Write')
) AS s ([ID], [CONTROLLERNAME], [ACTION])
ON t.[ID] = s.[ID]
WHEN NOT MATCHED THEN
    INSERT ([ID], [CONTROLLERNAME], [RETURNTYPE], [ATTRIBUTES], [ACTION])
    VALUES (s.[ID], s.[CONTROLLERNAME], NULL, NULL, s.[ACTION]);
GO

/* Administrator role -> screening permissions (guarded MAX(ID)+1 surrogate) */
INSERT INTO [dbo].[ROLESACTIONMAPPING]
    ([CONTROLLERID], [ROLEID], [ID], [ACTIVE], [CREATEDBY], [CREATEDDATE], [IPADDRESS])
SELECT s.[ControllerId], 1,
       (SELECT ISNULL(MAX([ID]), 0) FROM [dbo].[ROLESACTIONMAPPING]) + s.[RowNum],
       1, 'seed', SYSUTCDATETIME(), '127.0.0.1'
FROM (VALUES (90012, 1), (90013, 2)) AS s ([ControllerId], [RowNum])
WHERE NOT EXISTS (
    SELECT 1 FROM [dbo].[ROLESACTIONMAPPING] m
    WHERE m.[CONTROLLERID] = s.[ControllerId] AND m.[ROLEID] = 1 AND m.[ACTIVE] = 1
);
GO
