/* ============================================================
   AKA-CMS — Sprint 9: Master data lookups, workflow
   configuration, and reporting/dashboard stored procedures.

   Error numbers (project convention):
     50005 - row-version mismatch (optimistic concurrency -> 409)
     50008 - entity not found (-> 404)
     50009 - domain validation failure (-> 400)
   All write procs use TRY/CATCH and write CMS_AuditLogs rows.
   All aggregates are computed in SQL, never in C#.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================
   1. MASTER DATA LOOKUPS
   ============================================================ */

/* ---- sp_CMS_Lookup_Get ----
   One generic entry point; maps @LookupType to its source table.
   Supported types: crisis-types, psych-modalities, medications,
   risk-bands, screening-tools, case-sources, followup-types,
   workflow-states, facilities (HIS UNIT, read-only). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Lookup_Get]
    @LookupType VARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;

    IF (@LookupType = 'crisis-types')
    BEGIN
        SELECT [CrisisTypeCode] AS [Code],
               [DisplayName]    AS [Name],
               [Description]    AS [Description],
               [SortOrder]      AS [SortOrder],
               [IsActive]       AS [IsActive],
               [DefaultSeverity] AS [Extra]
        FROM [dbo].[CMS_CrisisTypes]
        WHERE [IsActive] = 1
        ORDER BY [SortOrder], [CrisisTypeCode];
        RETURN;
    END

    IF (@LookupType = 'psych-modalities')
    BEGIN
        SELECT [ModalityCode] AS [Code],
               [DisplayName]  AS [Name],
               [Description]  AS [Description],
               [SortOrder]    AS [SortOrder],
               [IsActive]     AS [IsActive],
               CAST(NULL AS NVARCHAR(200)) AS [Extra]
        FROM [dbo].[CMS_PsychModalityTypes]
        WHERE [IsActive] = 1
        ORDER BY [SortOrder], [ModalityCode];
        RETURN;
    END

    IF (@LookupType = 'medications')
    BEGIN
        SELECT [MedicationCode] AS [Code],
               [GenericName]    AS [Name],
               CAST(NULL AS NVARCHAR(500)) AS [Description],
               [SortOrder]      AS [SortOrder],
               [IsActive]       AS [IsActive],
               LTRIM(RTRIM(ISNULL([Strength], '') + ' ' + ISNULL([DosageForm], ''))) AS [Extra]
        FROM [dbo].[CMS_MedicationDictionary]
        WHERE [IsActive] = 1
        ORDER BY [SortOrder], [MedicationCode];
        RETURN;
    END

    IF (@LookupType = 'risk-bands')
    BEGIN
        SELECT [BandCode]   AS [Code],
               [BandName]   AS [Name],
               CAST(NULL AS NVARCHAR(500)) AS [Description],
               [SortOrder] AS [SortOrder],
               [IsActive]  AS [IsActive],
               [ToolCode]  AS [Extra]
        FROM [dbo].[CMS_ScreeningRiskBands]
        WHERE [IsActive] = 1
        ORDER BY [ToolCode], [SortOrder];
        RETURN;
    END

    IF (@LookupType = 'screening-tools')
    BEGIN
        SELECT [ToolCode]   AS [Code],
               [ToolName]   AS [Name],
               [Description] AS [Description],
               0            AS [SortOrder],
               [IsActive]   AS [IsActive],
               CAST([ItemCount] AS NVARCHAR(200)) AS [Extra]
        FROM [dbo].[CMS_ScreeningTools]
        WHERE [IsActive] = 1
        ORDER BY [ToolCode];
        RETURN;
    END

    IF (@LookupType = 'case-sources')
    BEGIN
        SELECT [SourceTypeCode] AS [Code],
               [DisplayName]    AS [Name],
               [Description]    AS [Description],
               [SortOrder]      AS [SortOrder],
               [IsActive]       AS [IsActive],
               CAST(NULL AS NVARCHAR(200)) AS [Extra]
        FROM [dbo].[CMS_CaseSourceTypes]
        WHERE [IsActive] = 1
        ORDER BY [SortOrder], [SourceTypeCode];
        RETURN;
    END

    IF (@LookupType = 'followup-types')
    BEGIN
        /* Static reference list (no backing table; the FollowUpType
           vocabulary is fixed by the follow-up module). */
        SELECT v.[Code], v.[Name],
               CAST(NULL AS NVARCHAR(500)) AS [Description],
               v.[SortOrder], CAST(1 AS BIT) AS [IsActive],
               CAST(NULL AS NVARCHAR(200)) AS [Extra]
        FROM (VALUES
            ('SCHEDULED',          'Scheduled follow-up',   1),
            ('QUARTERLY_RESCREEN', 'Quarterly rescreening', 2),
            ('RE_ENGAGEMENT',      'Re-engagement',         3)
        ) AS v ([Code], [Name], [SortOrder])
        ORDER BY v.[SortOrder];
        RETURN;
    END

    IF (@LookupType = 'workflow-states')
    BEGIN
        SELECT [StateCode]  AS [Code],
               [StateName]   AS [Name],
               [Description] AS [Description],
               [SortOrder]   AS [SortOrder],
               CAST(1 AS BIT) AS [IsActive],
               CASE WHEN [IsTerminal] = 1 THEN 'TERMINAL'
                    WHEN [IsInitial] = 1 THEN 'INITIAL'
                    ELSE '' END AS [Extra]
        FROM [dbo].[CMS_WorkflowStates]
        ORDER BY [SortOrder], [StateCode];
        RETURN;
    END

    IF (@LookupType = 'facilities')
    BEGIN
        /* HIS-owned facility directory: read-only view over UNIT. */
        SELECT CAST([CODE] AS VARCHAR(50)) AS [Code],
               CAST([NAME] AS NVARCHAR(200)) AS [Name],
               CAST(NULL AS NVARCHAR(500)) AS [Description],
               [CODE] AS [SortOrder],
               CAST(1 AS BIT) AS [IsActive],
               CAST([SHORTNAME] AS NVARCHAR(200)) AS [Extra]
        FROM [dbo].[UNIT]
        WHERE [ACTIVE] = 1
        ORDER BY [CODE];
        RETURN;
    END;

    THROW 50009, 'Unknown lookup type.', 1;
END
GO

/* ============================================================
   2. WORKFLOW CONFIGURATION (admin)
   ============================================================ */

/* ---- sp_CMS_WorkflowState_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowState_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [StateCode],
           [StateName],
           [Description],
           [IsInitial],
           [IsTerminal],
           [SortOrder]
    FROM [dbo].[CMS_WorkflowStates]
    ORDER BY [SortOrder], [StateCode];
END
GO

/* ---- sp_CMS_WorkflowTransition_GetAll ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowTransition_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [TransitionId],
           [FromState],
           [ActionCode],
           [ActionName],
           [ToState],
           [RequiredPermissionName],
           [SortOrder],
           [IsActive],
           [RowVersion]
    FROM [dbo].[CMS_WorkflowTransitions]
    ORDER BY [FromState], [SortOrder], [TransitionId];
END
GO

/* ---- sp_CMS_WorkflowTransition_Create ----
   Admin-only: adds a new transition edge after validating that
   both endpoint states exist (400 otherwise). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowTransition_Create]
    @FromState VARCHAR(30),
    @ActionCode VARCHAR(50),
    @ActionName NVARCHAR(100),
    @ToState VARCHAR(30),
    @RequiredPermissionName VARCHAR(100) = NULL,
    @SortOrder INT = 0,
    @PerformedBy INT,
    @IpAddress VARCHAR(45),
    @NewTransitionId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_WorkflowStates] WHERE [StateCode] = @FromState)
            THROW 50009, 'FromState does not exist.', 1;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_WorkflowStates] WHERE [StateCode] = @ToState)
            THROW 50009, 'ToState does not exist.', 1;

        IF (@ActionCode IS NULL OR LTRIM(RTRIM(@ActionCode)) = '')
            THROW 50009, 'ActionCode is required.', 1;

        IF (@ActionName IS NULL OR LTRIM(RTRIM(@ActionName)) = '')
            THROW 50009, 'ActionName is required.', 1;

        IF EXISTS (SELECT 1 FROM [dbo].[CMS_WorkflowTransitions]
                   WHERE [FromState] = @FromState AND [ActionCode] = @ActionCode)
            THROW 50009, 'A transition with this FromState and ActionCode already exists.', 1;

        INSERT INTO [dbo].[CMS_WorkflowTransitions]
            ([FromState], [ActionCode], [ActionName], [ToState],
             [RequiredPermissionName], [SortOrder], [IsActive])
        VALUES
            (@FromState, @ActionCode, @ActionName, @ToState,
             ISNULL(@RequiredPermissionName, ''), ISNULL(@SortOrder, 0), 1);

        SET @NewTransitionId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs]
            ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES
            ('CMS_WorkflowTransitions', CAST(@NewTransitionId AS VARCHAR(50)), 'INSERT', @PerformedBy,
             'Transition created: ' + @FromState + ' --[' + @ActionCode + ']--> ' + @ToState
             + ' (IP ' + ISNULL(@IpAddress, '') + ')');

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_WorkflowTransition_SetActive ----
   Admin-only: enables/disables a transition with RowVersion
   optimistic concurrency (50005 on stale -> 409). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowTransition_SetActive]
    @TransitionId INT,
    @IsActive BIT,
    @RowVersion BINARY(8),
    @PerformedBy INT,
    @IpAddress VARCHAR(45)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @CurrentRowVersion BINARY(8);

        SELECT @CurrentRowVersion = [RowVersion]
        FROM [dbo].[CMS_WorkflowTransitions] WITH (UPDLOCK, HOLDLOCK)
        WHERE [TransitionId] = @TransitionId;

        IF (@CurrentRowVersion IS NULL)
            THROW 50008, 'Workflow transition not found.', 1;

        IF (@CurrentRowVersion <> @RowVersion)
            THROW 50005, 'The transition was modified by another user.', 1;

        UPDATE [dbo].[CMS_WorkflowTransitions]
        SET [IsActive] = @IsActive
        WHERE [TransitionId] = @TransitionId;

        INSERT INTO [dbo].[CMS_AuditLogs]
            ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES
            ('CMS_WorkflowTransitions', CAST(@TransitionId AS VARCHAR(50)), 'UPDATE', @PerformedBy,
             'IsActive -> ' + CASE WHEN @IsActive = 1 THEN '1' ELSE '0' END
             + ' (IP ' + ISNULL(@IpAddress, '') + ')');

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ============================================================
   3. REPORTING / DASHBOARDS (read-only aggregates)
   ============================================================ */

/* ---- sp_CMS_Report_CaseSummary ----
   Result set 1: open+closed case counts by workflow state.
   Result set 2: case counts by latest screening risk band.
   Optional filters: @FromDate/@ToDate on case CreatedAt,
   @UnitCode = HIS facility unit of the member's active MR mapping. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Report_CaseSummary]
    @FromDate DATETIME2 = NULL,
    @ToDate DATETIME2 = NULL,
    @UnitCode INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH FilteredCases AS
    (
        SELECT c.[CaseId], c.[Status]
        FROM [dbo].[CMS_Cases] AS c
        WHERE c.[IsActive] = 1
          AND (@FromDate IS NULL OR c.[CreatedAt] >= @FromDate)
          AND (@ToDate IS NULL OR c.[CreatedAt] < @ToDate)
          AND (@UnitCode IS NULL OR EXISTS
          (
              SELECT 1
              FROM [dbo].[CMS_HisMrMappings] AS m
              WHERE m.[CommunityMemberId] = c.[CommunityMemberId]
                AND m.[IsActive] = 1
                AND m.[UnitCode] = @UnitCode
          ))
    )
    SELECT [CaseId], [Status]
    INTO #FilteredCases
    FROM FilteredCases;

    /* RS1: counts by workflow state */
    SELECT s.[StateCode] AS [StateCode],
           s.[StateName] AS [StateName],
           COUNT(fc.[CaseId]) AS [CaseCount]
    FROM [dbo].[CMS_WorkflowStates] AS s
    LEFT JOIN #FilteredCases AS fc ON fc.[Status] = s.[StateCode]
    GROUP BY s.[StateCode], s.[StateName], s.[SortOrder]
    ORDER BY s.[SortOrder], s.[StateCode];

    /* RS2: counts by latest screening risk band */
    SELECT ISNULL(ls.[RiskLevel], 'NOT_SCREENED') AS [RiskBand],
           COUNT(fc.[CaseId]) AS [CaseCount]
    FROM #FilteredCases AS fc
    OUTER APPLY
    (
        SELECT TOP (1) sc.[RiskLevel]
        FROM [dbo].[CMS_Screenings] AS sc
        WHERE sc.[CaseId] = fc.[CaseId]
        ORDER BY sc.[ScreenedAt] DESC, sc.[ScreeningId] DESC
    ) AS ls
    GROUP BY ISNULL(ls.[RiskLevel], 'NOT_SCREENED')
    ORDER BY [RiskBand];

    DROP TABLE #FilteredCases;
END
GO

/* ---- sp_CMS_Report_ScreeningSummary ----
   Result set 1: per-tool volume + score stats (count/avg/min/max).
   Result set 2: per-tool distribution by risk level.
   Optional filters: @ToolCode, @FromDate/@ToDate on ScreenedAt. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Report_ScreeningSummary]
    @ToolCode VARCHAR(20) = NULL,
    @FromDate DATETIME2 = NULL,
    @ToDate DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Filtered AS
    (
        SELECT sc.[ToolCode], sc.[RawScore], sc.[RiskLevel]
        FROM [dbo].[CMS_Screenings] AS sc
        WHERE (@ToolCode IS NULL OR sc.[ToolCode] = @ToolCode)
          AND (@FromDate IS NULL OR sc.[ScreenedAt] >= @FromDate)
          AND (@ToDate IS NULL OR sc.[ScreenedAt] < @ToDate)
    )
    SELECT [ToolCode], [RawScore], [RiskLevel]
    INTO #FilteredScreenings
    FROM Filtered;

    /* RS1: per-tool aggregates */
    SELECT t.[ToolCode] AS [ToolCode],
           t.[ToolName] AS [ToolName],
           COUNT(f.[RawScore]) AS [ScreeningCount],
           CAST(AVG(CAST(f.[RawScore] AS FLOAT)) AS DECIMAL(10,2)) AS [AvgScore],
           MIN(f.[RawScore]) AS [MinScore],
           MAX(f.[RawScore]) AS [MaxScore]
    FROM [dbo].[CMS_ScreeningTools] AS t
    LEFT JOIN #FilteredScreenings AS f ON f.[ToolCode] = t.[ToolCode]
    WHERE t.[IsActive] = 1
      AND (@ToolCode IS NULL OR t.[ToolCode] = @ToolCode)
    GROUP BY t.[ToolCode], t.[ToolName]
    ORDER BY t.[ToolCode];

    /* RS2: risk-level distribution per tool */
    SELECT f.[ToolCode] AS [ToolCode],
           f.[RiskLevel] AS [RiskLevel],
           COUNT(*) AS [ScreeningCount]
    FROM #FilteredScreenings AS f
    GROUP BY f.[ToolCode], f.[RiskLevel]
    ORDER BY f.[ToolCode], f.[RiskLevel];

    DROP TABLE #FilteredScreenings;
END
GO

/* ---- sp_CMS_Report_HelplineSummary ----
   Result set 1: calls by type (CRISIS vs GENERAL).
   Result set 2: calls by crisis severity.
   Optional filters: @FromDate/@ToDate on CallStartedAt. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Report_HelplineSummary]
    @FromDate DATETIME2 = NULL,
    @ToDate DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Filtered AS
    (
        SELECT h.[HelplineCallId],
               CASE WHEN h.[CrisisTypeCodes] IS NOT NULL
                         AND LTRIM(RTRIM(h.[CrisisTypeCodes])) <> ''
                    THEN 'CRISIS' ELSE 'GENERAL' END AS [CallType],
               ISNULL(h.[CrisisSeverity], 'NONE') AS [Severity]
        FROM [dbo].[CMS_HelplineCalls] AS h
        WHERE h.[IsActive] = 1
          AND (@FromDate IS NULL OR h.[CallStartedAt] >= @FromDate)
          AND (@ToDate IS NULL OR h.[CallStartedAt] < @ToDate)
    )
    SELECT [HelplineCallId], [CallType], [Severity]
    INTO #FilteredCalls
    FROM Filtered;

    /* RS1: by call type */
    SELECT [CallType], COUNT(*) AS [CallCount]
    FROM #FilteredCalls
    GROUP BY [CallType]
    ORDER BY [CallType];

    /* RS2: by severity (outcome proxy) */
    SELECT [Severity], COUNT(*) AS [CallCount]
    FROM #FilteredCalls
    GROUP BY [Severity]
    ORDER BY [Severity];

    DROP TABLE #FilteredCalls;
END
GO

/* ---- sp_CMS_Report_FollowUpCompliance ----
   Completed vs missed (vs scheduled/cancelled) follow-up counts.
   Optional filters: @FromDate/@ToDate on ScheduledDate,
   @UnitCode = HIS facility unit of the member's active MR mapping. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Report_FollowUpCompliance]
    @FromDate DATETIME2 = NULL,
    @ToDate DATETIME2 = NULL,
    @UnitCode INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT f.[Status] AS [Status],
           COUNT(*) AS [FollowUpCount]
    FROM [dbo].[CMS_FollowUps] AS f
    INNER JOIN [dbo].[CMS_Cases] AS c ON c.[CaseId] = f.[CaseId]
    WHERE f.[IsActive] = 1
      AND (@FromDate IS NULL OR f.[ScheduledDate] >= @FromDate)
      AND (@ToDate IS NULL OR f.[ScheduledDate] < @ToDate)
      AND (@UnitCode IS NULL OR EXISTS
      (
          SELECT 1
          FROM [dbo].[CMS_HisMrMappings] AS m
          WHERE m.[CommunityMemberId] = c.[CommunityMemberId]
            AND m.[IsActive] = 1
            AND m.[UnitCode] = @UnitCode
      ))
    GROUP BY f.[Status]
    ORDER BY f.[Status];
END
GO

/* ---- sp_CMS_Report_Workload ----
   Open cases per assigned caseworker (open = status is not a
   terminal workflow state); includes an UNASSIGNED bucket.
   Optional filter: @UnitCode = HIS facility unit of the member's
   active MR mapping. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Report_Workload]
    @UnitCode INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.[AssignedToUserId] AS [AssignedToUserId],
           u.[USERNAME] AS [Username],
           COUNT(*) AS [OpenCaseCount]
    FROM [dbo].[CMS_Cases] AS c
    INNER JOIN [dbo].[CMS_WorkflowStates] AS s ON s.[StateCode] = c.[Status]
    LEFT JOIN [dbo].[USERS] AS u ON u.[USERID] = c.[AssignedToUserId]
    WHERE c.[IsActive] = 1
      AND s.[IsTerminal] = 0
      AND (@UnitCode IS NULL OR EXISTS
      (
          SELECT 1
          FROM [dbo].[CMS_HisMrMappings] AS m
          WHERE m.[CommunityMemberId] = c.[CommunityMemberId]
            AND m.[IsActive] = 1
            AND m.[UnitCode] = @UnitCode
      ))
    GROUP BY c.[AssignedToUserId], u.[USERNAME]
    ORDER BY COUNT(*) DESC, c.[AssignedToUserId];
END
GO
