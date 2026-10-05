/* ============================================================
   AKA-CMS — Sprint 3: case lifecycle (workflow engine) procedures.

   The core procedure is sp_CMS_WorkflowTransition_Apply: it is the
   ONLY path that changes a case's Status. UpdateDetails/Assign
   never touch Status; they are RowVersion-checked detail writes.

   Custom THROW numbers:
     50005 - row-version mismatch (optimistic concurrency)
     50006 - transition not allowed from the case's current state
     50007 - performer lacks the transition's required permission
     50008 - case not found
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_Case_Create ----
   Registers a case; always starts at the INTAKE state. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Case_Create]
    @CommunityMemberId INT,
    @SourceType VARCHAR(30),
    @PriorityLevel VARCHAR(20) = NULL,
    @Notes NVARCHAR(2000) = NULL,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewCaseId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_CommunityMembers]
                       WHERE [MemberId] = @CommunityMemberId AND [IsActive] = 1)
            THROW 50008, 'Community member not found.', 1;

        DECLARE @CaseNumber VARCHAR(30) =
            'CMS-' + CAST(YEAR(SYSUTCDATETIME()) AS VARCHAR(4)) + '-'
            + RIGHT('000000' + CAST(NEXT VALUE FOR [dbo].[CMS_CaseNumberSeq] AS VARCHAR(10)), 6);

        INSERT INTO [dbo].[CMS_Cases]
            ([CaseNumber], [CommunityMemberId], [SourceType], [Status], [CurrentStep],
             [PriorityLevel], [Notes], [IsActive], [CreatedBy], [IpAddress])
        VALUES
            (@CaseNumber, @CommunityMemberId, @SourceType, 'INTAKE', 'Registered',
             @PriorityLevel, @Notes, 1, @CreatedBy, @IpAddress);

        SET @NewCaseId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_CaseHistories]
            ([CaseId], [FromState], [ToState], [ActionCode], [Comment], [PerformedBy], [IpAddress])
        VALUES
            (@NewCaseId, 'INTAKE', 'INTAKE', 'RegisterCase', 'Case registered into CMS.', @CreatedBy, @IpAddress);

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Cases', CAST(@NewCaseId AS VARCHAR(50)), 'INSERT', @CreatedBy, @CaseNumber);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Case_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Case_GetById]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  c.[CaseId],
            c.[CaseNumber],
            c.[CommunityMemberId],
            cm.[FullName] AS [MemberName],
            cm.[MrNo] AS [MemberMrNo],
            c.[SourceType],
            c.[Status],
            s.[StateName] AS [StatusName],
            c.[CurrentStep],
            c.[AssignedToUserId],
            u.[USERNAME] AS [AssignedToUsername],
            c.[PriorityLevel],
            c.[Notes],
            c.[RowVersion],
            c.[IsActive],
            c.[CreatedBy],
            c.[CreatedAt],
            c.[ModifiedBy],
            c.[ModifiedAt]
    FROM [dbo].[CMS_Cases] c
    INNER JOIN [dbo].[CMS_WorkflowStates] s ON s.[StateCode] = c.[Status]
    LEFT JOIN [dbo].[CMS_CommunityMembers] cm ON cm.[MemberId] = c.[CommunityMemberId]
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = c.[AssignedToUserId]
    WHERE c.[CaseId] = @CaseId AND c.[IsActive] = 1;
END
GO

/* ---- sp_CMS_Case_UpdateDetails ----
   Details only: Notes and PriorityLevel. Status and CurrentStep are
   deliberately NOT parameters — they change only through
   sp_CMS_WorkflowTransition_Apply. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Case_UpdateDetails]
    @CaseId INT,
    @PriorityLevel VARCHAR(20) = NULL,
    @Notes NVARCHAR(2000) = NULL,
    @RowVersion BINARY(8),
    @PerformedBy INT,
    @IpAddress VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Current ROWVERSION;
        SELECT @Current = [RowVersion]
        FROM [dbo].[CMS_Cases]
        WHERE [CaseId] = @CaseId AND [IsActive] = 1;

        IF @Current IS NULL
            THROW 50008, 'Case not found.', 1;

        IF @Current <> @RowVersion
            THROW 50005, 'The case was modified by another user. Reload and try again.', 1;

        UPDATE [dbo].[CMS_Cases]
        SET [PriorityLevel] = @PriorityLevel,
            [Notes] = @Notes,
            [ModifiedBy] = @PerformedBy,
            [ModifiedAt] = SYSUTCDATETIME(),
            [IpAddress] = @IpAddress
        WHERE [CaseId] = @CaseId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Cases', CAST(@CaseId AS VARCHAR(50)), 'UPDATE-DETAILS', @PerformedBy, 'Case details updated.');

        COMMIT TRAN;

        EXEC [dbo].[sp_CMS_Case_GetById] @CaseId = @CaseId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Case_Assign ----
   Re-assigns the case manager without changing Status. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Case_Assign]
    @CaseId INT,
    @UserId INT,
    @RowVersion BINARY(8),
    @PerformedBy INT,
    @IpAddress VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Current ROWVERSION;
        SELECT @Current = [RowVersion]
        FROM [dbo].[CMS_Cases]
        WHERE [CaseId] = @CaseId AND [IsActive] = 1;

        IF @Current IS NULL
            THROW 50008, 'Case not found.', 1;

        IF @Current <> @RowVersion
            THROW 50005, 'The case was modified by another user. Reload and try again.', 1;

        IF NOT EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERID] = @UserId AND [ACTIVE] = 1)
            THROW 50008, 'User not found.', 1;

        UPDATE [dbo].[CMS_Cases]
        SET [AssignedToUserId] = @UserId,
            [ModifiedBy] = @PerformedBy,
            [ModifiedAt] = SYSUTCDATETIME(),
            [IpAddress] = @IpAddress
        WHERE [CaseId] = @CaseId;

        INSERT INTO [dbo].[CMS_CaseHistories]
            ([CaseId], [FromState], [ToState], [ActionCode], [Comment], [PerformedBy], [IpAddress])
        SELECT @CaseId, [Status], [Status], 'AssignCaseManager',
               'Case reassigned to user ' + CAST(@UserId AS VARCHAR(20)), @PerformedBy, @IpAddress
        FROM [dbo].[CMS_Cases]
        WHERE [CaseId] = @CaseId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Cases', CAST(@CaseId AS VARCHAR(50)), 'ASSIGN', @PerformedBy,
                'Assigned to user ' + CAST(@UserId AS VARCHAR(20)));

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_WorkflowTransition_Apply ----
   THE core workflow procedure: the only path that changes a case's
   Status. Validates existence, terminal state, allowed action,
   permission and concurrency, then atomically writes history and
   updates the case. @HasPermission is computed by the application
   layer from the authenticated user's JWT permission claims against
   the transition's RequiredPermissionName. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowTransition_Apply]
    @CaseId INT,
    @ActionCode VARCHAR(50),
    @Comment NVARCHAR(1000) = NULL,
    @AssignedToUserId INT = NULL,
    @RowVersion BINARY(8),
    @HasPermission BIT,
    @PerformedBy INT,
    @IpAddress VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @Current ROWVERSION, @FromState VARCHAR(30), @IsTerminal BIT;

        SELECT @Current = c.[RowVersion], @FromState = c.[Status], @IsTerminal = s.[IsTerminal]
        FROM [dbo].[CMS_Cases] c
        INNER JOIN [dbo].[CMS_WorkflowStates] s ON s.[StateCode] = c.[Status]
        WHERE c.[CaseId] = @CaseId AND c.[IsActive] = 1;

        IF @Current IS NULL
            THROW 50008, 'Case not found.', 1;

        IF @IsTerminal = 1
            THROW 50006, 'Case is in a terminal state; no transitions are allowed.', 1;

        IF @Current <> @RowVersion
            THROW 50005, 'The case was modified by another user. Reload and try again.', 1;

        DECLARE @ToState VARCHAR(30), @RequiredPermission VARCHAR(100);

        SELECT @ToState = [ToState], @RequiredPermission = [RequiredPermissionName]
        FROM [dbo].[CMS_WorkflowTransitions]
        WHERE [FromState] = @FromState AND [ActionCode] = @ActionCode AND [IsActive] = 1;

        IF @ToState IS NULL
            THROW 50006, 'Transition is not allowed from the current state.', 1;

        IF @RequiredPermission IS NOT NULL AND @RequiredPermission <> '' AND @HasPermission = 0
            THROW 50007, 'You do not have permission to perform this transition.', 1;

        IF @AssignedToUserId IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM [dbo].[USERS] WHERE [USERID] = @AssignedToUserId AND [ACTIVE] = 1)
            THROW 50008, 'User not found.', 1;

        /* Gap 4 — workflow S16: a case manager may only be assigned
           after the case-management supervisor has reviewed the case
           (SubmitSupervisorReview stamps SupervisorReviewedAt). */
        IF @ActionCode = 'AssignCaseManager'
           AND NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases]
                           WHERE [CaseId] = @CaseId AND [SupervisorReviewedAt] IS NOT NULL)
            THROW 50006, 'Supervisor review is required before assigning a case manager.', 1;

        /* Gap 4 — record the supervisor review (self-loop on TRIAGE). */
        IF @ActionCode = 'SubmitSupervisorReview'
        BEGIN
            UPDATE [dbo].[CMS_Cases]
            SET [SupervisorReviewedAt] = SYSUTCDATETIME(),
                [SupervisorReviewedBy] = @PerformedBy
            WHERE [CaseId] = @CaseId;
        END

        UPDATE [dbo].[CMS_Cases]
        SET [Status] = @ToState,
            [CurrentStep] = @ActionCode,
            [AssignedToUserId] = ISNULL(@AssignedToUserId, [AssignedToUserId]),
            [ModifiedBy] = @PerformedBy,
            [ModifiedAt] = SYSUTCDATETIME(),
            [IpAddress] = @IpAddress
        WHERE [CaseId] = @CaseId;

        INSERT INTO [dbo].[CMS_CaseHistories]
            ([CaseId], [FromState], [ToState], [ActionCode], [Comment], [PerformedBy], [IpAddress])
        VALUES
            (@CaseId, @FromState, @ToState, @ActionCode, @Comment, @PerformedBy, @IpAddress);

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Cases', CAST(@CaseId AS VARCHAR(50)), 'TRANSITION', @PerformedBy,
                @FromState + ' -> ' + @ToState + ' (' + @ActionCode + ')');

        /* Gap 5 — workflow S5a-S5d: auto-create the no-consent
           re-engagement checklist (idempotent; at most one active
           NO_CONSENT plan per case). */
        IF @ActionCode = 'MarkNoConsent'
        BEGIN
            EXEC [dbo].[sp_CMS_NoConsentChecklist_Create]
                @CaseId = @CaseId, @CreatedBy = @PerformedBy, @IpAddress = @IpAddress;
        END

        COMMIT TRAN;

        EXEC [dbo].[sp_CMS_Case_GetById] @CaseId = @CaseId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_WorkflowTransition_GetAllowed ----
   Allowed actions from a case's current state. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_WorkflowTransition_GetAllowed]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @FromState VARCHAR(30);

    SELECT @FromState = [Status]
    FROM [dbo].[CMS_Cases]
    WHERE [CaseId] = @CaseId AND [IsActive] = 1;

    IF @FromState IS NULL
        THROW 50008, 'Case not found.', 1;

    SELECT  tr.[ActionCode],
            tr.[ActionName],
            tr.[FromState],
            tr.[ToState],
            ts.[StateName] AS [ToStateName],
            tr.[RequiredPermissionName],
            tr.[SortOrder]
    FROM [dbo].[CMS_WorkflowTransitions] tr
    INNER JOIN [dbo].[CMS_WorkflowStates] ts ON ts.[StateCode] = tr.[ToState]
    WHERE tr.[FromState] = @FromState AND tr.[IsActive] = 1
    ORDER BY tr.[SortOrder];
END
GO

/* ---- sp_CMS_CaseHistory_GetByCase ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_CaseHistory_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    SELECT  h.[HistoryId],
            h.[CaseId],
            h.[FromState],
            h.[ToState],
            h.[ActionCode],
            h.[Comment],
            h.[PerformedBy],
            u.[USERNAME] AS [PerformedByUsername],
            h.[PerformedAt],
            h.[IpAddress]
    FROM [dbo].[CMS_CaseHistories] h
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = h.[PerformedBy]
    WHERE h.[CaseId] = @CaseId
    ORDER BY h.[HistoryId];
END
GO

/* ---- sp_CMS_Case_List ----
   Paged, searchable list of active cases for pickers and queues.
   @Search matches case number, member name, or MR number.
   Every row carries TotalCount for client-side paging. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Case_List]
    @Search   NVARCHAR(100) = NULL,
    @Page     INT = 1,
    @PageSize INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    IF (@Page < 1) SET @Page = 1;
    IF (@PageSize < 1 OR @PageSize > 100) SET @PageSize = 20;

    DECLARE @Offset INT = (@Page - 1) * @PageSize;

    ;WITH Filtered AS (
        SELECT  c.[CaseId],
                c.[CaseNumber],
                c.[CommunityMemberId],
                cm.[FullName] AS [MemberName],
                cm.[MrNo]     AS [MemberMrNo],
                c.[Status],
                s.[StateName] AS [StatusName],
                c.[PriorityLevel],
                c.[CreatedAt]
        FROM [dbo].[CMS_Cases] c
        INNER JOIN [dbo].[CMS_WorkflowStates] s ON s.[StateCode] = c.[Status]
        LEFT JOIN [dbo].[CMS_CommunityMembers] cm ON cm.[MemberId] = c.[CommunityMemberId]
        WHERE c.[IsActive] = 1
          AND (@Search IS NULL OR @Search = ''
               OR c.[CaseNumber] LIKE '%' + @Search + '%'
               OR cm.[FullName]  LIKE '%' + @Search + '%'
               OR cm.[MrNo]      LIKE '%' + @Search + '%')
    )
    SELECT  f.*,
            COUNT(*) OVER() AS [TotalCount]
    FROM Filtered f
    ORDER BY f.[CaseId] DESC
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;
END
GO
