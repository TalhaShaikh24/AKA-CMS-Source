/* ============================================================
   AKA-CMS - Sprint 4 seed data (09)
   Screening tools (PHQ-9, GAD-7) with standard scoring bands,
   plus permission catalog entries 90012 Screenings:Read and
   90013 Screenings:Write granted to the Administrator role.

   PHQ-9 bands (standard): 0-4 Minimal, 5-9 Mild, 10-14 Moderate,
   15-19 Moderately severe, 20-27 Severe.
   GAD-7 bands (standard): 0-4 Minimal, 5-9 Mild, 10-14 Moderate,
   15-21 Severe.
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
     7, 3, 0, 21)
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
    ('GAD7', 'SEVERE',    'Severe',           15, 21, 40)
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
