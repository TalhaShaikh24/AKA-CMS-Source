/* ============================================================
   AKA-CMS — Gap-closure stored procedures (17)
   Closes workflow gaps identified against the client workflow
   sheet (Cases tab, S1-S38).

   Gap 3 (Engage Carers — S5b/S20-High/S19-Mod/S19-Low/S35):
     sp_CMS_Carer_GetByCase / Add / Update / Deactivate.
     Soft-deactivate only; RowVersion concurrency (50005);
     50008 not found; 50009 validation.

   Gap 5 (No-consent sub-steps — S5a-S5d):
     sp_CMS_NoConsentChecklist_Create — auto-creates the
     4-step re-engagement checklist as a CMS_ActionCarePlans row
     (reuses the existing care-plan JSON-steps mechanism and the
     existing care-plan read endpoints). Idempotent: one active
     NO_CONSENT plan per case. Called from
     sp_CMS_WorkflowTransition_Apply when MarkNoConsent is applied.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_Carer_GetByCase ----
   Active carers for a case, primary first. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Carer_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    SELECT [CarerId], [CaseId], [FullName], [Relationship], [Phone],
           [IsPrimary], [IsActive], c.[CreatedBy],
           u.[USERNAME] AS [CreatedByUsername],
           [CreatedAt], [ModifiedBy], [ModifiedAt], c.[IpAddress], [RowVersion]
    FROM [dbo].[CMS_Carers] c
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = c.[CreatedBy]
    WHERE c.[CaseId] = @CaseId AND c.[IsActive] = 1
    ORDER BY c.[IsPrimary] DESC, c.[CreatedAt] ASC;
END
GO

/* ---- sp_CMS_Carer_Add ----
   Adds a carer to a case. When @IsPrimary = 1, any other primary
   carer on the case is demoted first (single primary per case). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Carer_Add]
    @CaseId INT,
    @FullName NVARCHAR(200),
    @Relationship NVARCHAR(100) = NULL,
    @Phone VARCHAR(30) = NULL,
    @IsPrimary BIT = 0,
    @PerformedBy INT,
    @IpAddress VARCHAR(45) = NULL,
    @NewCarerId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    IF LEN(LTRIM(RTRIM(ISNULL(@FullName, N'')))) = 0
        THROW 50009, 'Carer full name is required.', 1;

    BEGIN TRY
        BEGIN TRAN;

        IF @IsPrimary = 1
        BEGIN
            UPDATE [dbo].[CMS_Carers]
            SET [IsPrimary] = 0, [ModifiedBy] = @PerformedBy,
                [ModifiedAt] = SYSUTCDATETIME(), [IpAddress] = @IpAddress
            WHERE [CaseId] = @CaseId AND [IsActive] = 1 AND [IsPrimary] = 1;
        END

        INSERT INTO [dbo].[CMS_Carers]
            ([CaseId], [FullName], [Relationship], [Phone], [IsPrimary],
             [CreatedBy], [IpAddress])
        VALUES
            (@CaseId, LTRIM(RTRIM(@FullName)), NULLIF(LTRIM(RTRIM(@Relationship)), N''),
             NULLIF(LTRIM(RTRIM(@Phone)), ''), @IsPrimary, @PerformedBy, @IpAddress);

        SET @NewCarerId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Carers', CAST(@NewCarerId AS VARCHAR(50)), 'INSERT', @PerformedBy,
                'Carer added to case ' + CAST(@CaseId AS VARCHAR(20)));

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Carer_Update ----
   Updates a carer. RowVersion concurrency (50005). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Carer_Update]
    @CarerId INT,
    @CaseId INT,
    @FullName NVARCHAR(200),
    @Relationship NVARCHAR(100) = NULL,
    @Phone VARCHAR(30) = NULL,
    @IsPrimary BIT = 0,
    @RowVersion BINARY(8),
    @PerformedBy INT,
    @IpAddress VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Current ROWVERSION;

    SELECT @Current = [RowVersion]
    FROM [dbo].[CMS_Carers]
    WHERE [CarerId] = @CarerId AND [CaseId] = @CaseId AND [IsActive] = 1;

    IF @Current IS NULL
        THROW 50008, 'Carer not found.', 1;

    IF @Current <> @RowVersion
        THROW 50005, 'The carer was modified by another user. Reload and try again.', 1;

    IF LEN(LTRIM(RTRIM(ISNULL(@FullName, N'')))) = 0
        THROW 50009, 'Carer full name is required.', 1;

    BEGIN TRY
        BEGIN TRAN;

        IF @IsPrimary = 1
        BEGIN
            UPDATE [dbo].[CMS_Carers]
            SET [IsPrimary] = 0, [ModifiedBy] = @PerformedBy,
                [ModifiedAt] = SYSUTCDATETIME(), [IpAddress] = @IpAddress
            WHERE [CaseId] = @CaseId AND [IsActive] = 1
              AND [IsPrimary] = 1 AND [CarerId] <> @CarerId;
        END

        UPDATE [dbo].[CMS_Carers]
        SET [FullName] = LTRIM(RTRIM(@FullName)),
            [Relationship] = NULLIF(LTRIM(RTRIM(@Relationship)), N''),
            [Phone] = NULLIF(LTRIM(RTRIM(@Phone)), ''),
            [IsPrimary] = @IsPrimary,
            [ModifiedBy] = @PerformedBy,
            [ModifiedAt] = SYSUTCDATETIME(),
            [IpAddress] = @IpAddress
        WHERE [CarerId] = @CarerId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_Carers', CAST(@CarerId AS VARCHAR(50)), 'UPDATE', @PerformedBy,
                'Carer updated on case ' + CAST(@CaseId AS VARCHAR(20)));

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_Carer_Deactivate ----
   Soft-deactivates a carer (no hard delete). RowVersion
   concurrency (50005). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Carer_Deactivate]
    @CarerId INT,
    @CaseId INT,
    @RowVersion BINARY(8),
    @PerformedBy INT,
    @IpAddress VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Current ROWVERSION;

    SELECT @Current = [RowVersion]
    FROM [dbo].[CMS_Carers]
    WHERE [CarerId] = @CarerId AND [CaseId] = @CaseId AND [IsActive] = 1;

    IF @Current IS NULL
        THROW 50008, 'Carer not found.', 1;

    IF @Current <> @RowVersion
        THROW 50005, 'The carer was modified by another user. Reload and try again.', 1;

    UPDATE [dbo].[CMS_Carers]
    SET [IsActive] = 0,
        [ModifiedBy] = @PerformedBy,
        [ModifiedAt] = SYSUTCDATETIME(),
        [IpAddress] = @IpAddress
    WHERE [CarerId] = @CarerId;

    INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
    VALUES ('CMS_Carers', CAST(@CarerId AS VARCHAR(50)), 'DEACTIVATE', @PerformedBy,
            'Carer deactivated on case ' + CAST(@CaseId AS VARCHAR(20)));
END
GO

/* ---- sp_CMS_NoConsentChecklist_Create ----
   Gap 5: when MarkNoConsent is applied, auto-create the 4-step
   re-engagement checklist (workflow S5a-S5d) as an
   CMS_ActionCarePlans row so it is visible through the existing
   care-plan read endpoints. Idempotent: creates at most one
   active NO_CONSENT plan per case. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_NoConsentChecklist_Create]
    @CaseId INT,
    @CreatedBy INT,
    @IpAddress VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_Cases] WHERE [CaseId] = @CaseId AND [IsActive] = 1)
        THROW 50008, 'Case not found.', 1;

    IF EXISTS (SELECT 1 FROM [dbo].[CMS_ActionCarePlans]
               WHERE [CaseId] = @CaseId AND [RiskCategory] = 'NO_CONSENT'
                 AND [IsActive] = 1 AND [Status] = 'ACTIVE')
        RETURN;

    DECLARE @StepsJson NVARCHAR(MAX) =
        N'[{"stepCode":"S5a","title":"Provide Information & Psychoeducation","status":"PENDING"},' +
        N'{"stepCode":"S5b","title":"Engage Carers if applicable","status":"PENDING"},' +
        N'{"stepCode":"S5c","title":"Schedule Re-engagement Attempt","status":"PENDING"},' +
        N'{"stepCode":"S5d","title":"Supervisor Review & Connecting to Care","status":"PENDING"}]';

    INSERT INTO [dbo].[CMS_ActionCarePlans]
        ([CaseId], [RiskCategory], [Title], [StepsJson], [Status], [CreatedBy], [IpAddress])
    VALUES
        (@CaseId, 'NO_CONSENT', 'No-Consent Re-engagement Checklist (S5a-S5d)',
         @StepsJson, 'ACTIVE', @CreatedBy, @IpAddress);

    INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
    VALUES ('CMS_ActionCarePlans', CAST(SCOPE_IDENTITY() AS VARCHAR(50)), 'INSERT', @CreatedBy,
            'No-consent re-engagement checklist created for case ' + CAST(@CaseId AS VARCHAR(20)));
END
GO
