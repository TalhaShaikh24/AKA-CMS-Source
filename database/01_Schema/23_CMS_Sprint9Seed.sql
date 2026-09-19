/* ============================================================
   AKA-CMS — Sprint 9 seed: permission catalog entries for
   master-data lookups, workflow configuration, and reports.
   IDs continue the CMS-reserved sequence (>= 90000) via a
   guarded MAX(ID)+1 so the block is idempotent and never
   collides with an existing row.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- Permission catalog entries (guarded, idempotent) ---- */
INSERT INTO [dbo].[AllCONTROLLERS]
    ([ID], [CONTROLLERNAME], [RETURNTYPE], [ATTRIBUTES], [ACTION])
SELECT v.[ID], v.[CONTROLLERNAME], NULL, NULL, v.[ACTION]
FROM
(
    SELECT defs.[CONTROLLERNAME],
           defs.[ACTION],
           (SELECT ISNULL(MAX([ID]), 90051)
            FROM [dbo].[AllCONTROLLERS] WITH (UPDLOCK, HOLDLOCK)
            WHERE [ID] >= 90000)
           + ROW_NUMBER() OVER (ORDER BY defs.[CONTROLLERNAME], defs.[ACTION]) AS [ID]
    FROM (VALUES
        ('Lookups',        'Read'),
        ('Reports',        'Read'),
        ('WorkflowConfig', 'Read'),
        ('WorkflowConfig', 'Write')
    ) AS defs ([CONTROLLERNAME], [ACTION])
) AS v
WHERE NOT EXISTS
(
    SELECT 1
    FROM [dbo].[AllCONTROLLERS] AS t
    WHERE t.[CONTROLLERNAME] = v.[CONTROLLERNAME]
      AND t.[ACTION] = v.[ACTION]
);
GO

/* ---- Grant the four new permissions to the admin role (RoleId = 1) ----
   Uses sp_CMS_Role_AssignPermission (never a direct ROLEACTIONMAPPING
   insert — the local catalog has a quirk that breaks direct inserts). */
DECLARE @PermissionId INT;

DECLARE grant_cur CURSOR LOCAL FAST_FORWARD FOR
SELECT [ID]
FROM [dbo].[AllCONTROLLERS]
WHERE [CONTROLLERNAME] IN ('Lookups', 'Reports', 'WorkflowConfig')
ORDER BY [ID];

OPEN grant_cur;
FETCH NEXT FROM grant_cur INTO @PermissionId;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC [dbo].[sp_CMS_Role_AssignPermission]
        @RoleId = 1,
        @ControllerActionId = @PermissionId,
        @CreatedBy = 'seed',
        @PerformedBy = 1;
    FETCH NEXT FROM grant_cur INTO @PermissionId;
END
CLOSE grant_cur;
DEALLOCATE grant_cur;
GO
