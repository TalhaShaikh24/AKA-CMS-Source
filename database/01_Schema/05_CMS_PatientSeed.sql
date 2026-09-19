/* ============================================================
   AKA-CMS — Sprint 2 seed data (05)
   Inserts only; safe to re-run (guarded by MERGE / NOT EXISTS).

   NOTE: facility MR block ranges below are PLACEHOLDERS
   (IsPlaceholder = 1). The handoff doc flags MrBlockStart/MrBlockEnd
   as an unconfirmed open item — confirm real ranges per facility
   with the client and update via PUT /api/patients/mr-blocks.
   UnitCodes 1-8 follow the 8 remote sites in the flow diagram
   (AKH Gilgit, AKDC Jutial, AKDC Gahkuch, EFHC Aliabad,
   Singul Medical Centre, AKMC Booni, AKDC Chitral, RHC Shagram).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* CMS permission catalog entries for patient identity (IDs >= 90000) */
MERGE INTO [dbo].[AllCONTROLLERS] AS t
USING (VALUES
    (90007, 'Patients', 'Read'),
    (90008, 'Patients', 'Write')
) AS s ([ID], [CONTROLLERNAME], [ACTION])
ON t.[ID] = s.[ID]
WHEN NOT MATCHED THEN
    INSERT ([ID], [CONTROLLERNAME], [RETURNTYPE], [ATTRIBUTES], [ACTION])
    VALUES (s.[ID], s.[CONTROLLERNAME], NULL, NULL, s.[ACTION]);
GO

/* Administrator role -> patient permissions.
   NOTE: ROLESACTIONMAPPING.[ID] is a surrogate filled by MAX(ID)+1
   whenever permissions are granted at runtime, so the seed must NOT
   reuse the AllCONTROLLERS id as the mapping id. */
INSERT INTO [dbo].[ROLESACTIONMAPPING]
    ([CONTROLLERID], [ROLEID], [ID], [ACTIVE], [CREATEDBY], [CREATEDDATE], [IPADDRESS])
SELECT s.[ControllerId], 1,
       (SELECT ISNULL(MAX([ID]), 0) FROM [dbo].[ROLESACTIONMAPPING]) + s.[RowNum],
       1, 'seed', SYSUTCDATETIME(), '127.0.0.1'
FROM (VALUES (90007, 1), (90008, 2)) AS s ([ControllerId], [RowNum])
WHERE NOT EXISTS (
    SELECT 1 FROM [dbo].[ROLESACTIONMAPPING] m
    WHERE m.[CONTROLLERID] = s.[ControllerId] AND m.[ROLEID] = 1 AND m.[ACTIVE] = 1
);
GO

/* Placeholder dummy-MR blocks, one per remote site */
MERGE INTO [dbo].[CMS_FacilityMrBlocks] AS t
USING (VALUES
    (1, 'TMP', 1, 999999),
    (2, 'TMP', 1, 999999),
    (3, 'TMP', 1, 999999),
    (4, 'TMP', 1, 999999),
    (5, 'TMP', 1, 999999),
    (6, 'TMP', 1, 999999),
    (7, 'TMP', 1, 999999),
    (8, 'TMP', 1, 999999)
) AS s ([UnitCode], [MrPrefix], [BlockStart], [BlockEnd])
ON t.[UnitCode] = s.[UnitCode] AND t.[IsActive] = 1
WHEN NOT MATCHED THEN
    INSERT ([UnitCode], [MrPrefix], [BlockStart], [BlockEnd], [NextSequence], [IsPlaceholder], [IsActive], [CreatedBy])
    VALUES (s.[UnitCode], s.[MrPrefix], s.[BlockStart], s.[BlockEnd], s.[BlockStart], 1, 1, 1);
GO
