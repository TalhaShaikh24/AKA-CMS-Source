/* ============================================================
   AKA-CMS — Health check (Sprint 10 hardening)
   Run after the 01_Schema scripts and before/after the other
   02_StoredProcedures scripts; it has no dependencies.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.sp_CMS_Health_Check', N'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_CMS_Health_Check;
GO

CREATE PROCEDURE dbo.sp_CMS_Health_Check
AS
BEGIN
    SET NOCOUNT ON;
    -- Trivial liveness ping: proves the connection + DB are reachable.
    SELECT 1 AS DbOk, SYSUTCDATETIME() AS DbUtcTime;
END;
GO
