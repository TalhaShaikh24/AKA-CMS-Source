/* ============================================================
   AKA-CMS — Permission catalog stored procedures
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_Permission_GetCatalog ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Permission_GetCatalog]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [ID] AS [Id],
           [CONTROLLERNAME] AS [ControllerName],
           [ACTION] AS [Action]
    FROM [dbo].[AllCONTROLLERS]
    ORDER BY [CONTROLLERNAME], [ACTION];
END
GO
