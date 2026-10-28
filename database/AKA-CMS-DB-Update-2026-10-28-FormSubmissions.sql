/* ============================================================================
   44_CMS_DynamicFormSubmissions.sql
   Dynamic Form Builder — submission entries.
   - CMS_DynamicFormSubmissions: one row per filled-in form (who, when).
   - CMS_DynamicFormSubmissionValues: one row per answered field. The value
     is stored as JSON text (ValueJson) so every field type round-trips:
     a string stays a string, a multi-select stays an array, a grid stays
     an array of row objects, a checkbox stays a boolean. File fields
     store the stored file's relative path (under the API uploads folder).
   - Permission: DynamicForms Submit (dynamic catalog, like Read/Write).
   Idempotent: safe to re-run.
   ============================================================================ */
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'[dbo].[CMS_DynamicFormSubmissions]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_DynamicFormSubmissions] (
        [SubmissionId] INT IDENTITY(1,1) NOT NULL,
        [FormId]       INT NOT NULL,
        [SubmittedBy]  INT NULL,   -- USERS.USERID of the submitter (JWT)
        [SubmittedAt]  DATETIME2 NOT NULL CONSTRAINT [DF_CMS_DynamicFormSubmissions_SubmittedAt] DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT [PK_CMS_DynamicFormSubmissions] PRIMARY KEY CLUSTERED ([SubmissionId]),
        CONSTRAINT [FK_CMS_DynamicFormSubmissions_Form] FOREIGN KEY ([FormId])
            REFERENCES [dbo].[CMS_DynamicForms] ([FormId]) ON DELETE CASCADE
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_DynamicFormSubmissions_Form]
        ON [dbo].[CMS_DynamicFormSubmissions] ([FormId], [SubmittedAt] DESC, [SubmissionId] DESC);
END
GO

IF OBJECT_ID(N'[dbo].[CMS_DynamicFormSubmissionValues]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[CMS_DynamicFormSubmissionValues] (
        [ValueId]      INT IDENTITY(1,1) NOT NULL,
        [SubmissionId] INT NOT NULL,
        [FieldKey]     VARCHAR(100) NOT NULL,
        [ValueJson]    NVARCHAR(MAX) NULL,  -- JSON text of the submitted value
        CONSTRAINT [PK_CMS_DynamicFormSubmissionValues] PRIMARY KEY CLUSTERED ([ValueId]),
        CONSTRAINT [FK_CMS_DynamicFormSubmissionValues_Submission] FOREIGN KEY ([SubmissionId])
            REFERENCES [dbo].[CMS_DynamicFormSubmissions] ([SubmissionId]) ON DELETE CASCADE
    );
    CREATE NONCLUSTERED INDEX [IX_CMS_DynamicFormSubmissionValues_Submission]
        ON [dbo].[CMS_DynamicFormSubmissionValues] ([SubmissionId], [FieldKey]);
END
GO

/* ---- Permission catalog entry: DynamicForms Submit ---- */
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
        ('DynamicForms', 'Submit')
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

/* ---- Grants: roles 1-2 already hold Read+Write, roles 3-5 hold Read.
   Submit for all five gives 1-2 full access and 3-5 Read+Submit (they
   can fill forms but cannot edit form definitions). ---- */
DECLARE @DfSubmit INT;
SELECT @DfSubmit = [ID] FROM [dbo].[AllCONTROLLERS] WHERE [CONTROLLERNAME] = 'DynamicForms' AND [ACTION] = 'Submit';

EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = @DfSubmit, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 2, @ControllerActionId = @DfSubmit, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 3, @ControllerActionId = @DfSubmit, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 4, @ControllerActionId = @DfSubmit, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 5, @ControllerActionId = @DfSubmit, @CreatedBy = 'seed', @PerformedBy = 1;
GO
/* ============================================================================
   32_DynamicFormSubmissions.sql
   Dynamic Form Builder — submission entry stored procedures.
   Values arrive as one JSON array (@ValuesJson): [{fieldKey, valueJson}]
   where valueJson is the JSON text of the submitted value (already
   encoded by the API), so every field type round-trips exactly.
   ============================================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_DynamicFormSubmission_Submit ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_DynamicFormSubmission_Submit]
    @FormId INT,
    @SubmittedBy INT = NULL,
    @ValuesJson NVARCHAR(MAX) = NULL,   -- array of {fieldKey, valueJson}
    @NewSubmissionId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        INSERT INTO [dbo].[CMS_DynamicFormSubmissions] ([FormId], [SubmittedBy])
        VALUES (@FormId, @SubmittedBy);
        SET @NewSubmissionId = CAST(SCOPE_IDENTITY() AS INT);

        IF @ValuesJson IS NOT NULL AND ISJSON(@ValuesJson) = 1
        BEGIN
            INSERT INTO [dbo].[CMS_DynamicFormSubmissionValues]
                ([SubmissionId], [FieldKey], [ValueJson])
            SELECT  @NewSubmissionId, j.[FieldKey], j.[ValueJson]
            FROM OPENJSON(@ValuesJson)
            WITH (
                [FieldKey]  VARCHAR(100)  '$.fieldKey',
                [ValueJson] NVARCHAR(MAX) '$.valueJson'
            ) AS j
            WHERE j.[FieldKey] IS NOT NULL;
        END

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy])
        VALUES ('CMS_DynamicFormSubmissions', CAST(@NewSubmissionId AS VARCHAR(50)), 'INSERT', @SubmittedBy);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_DynamicFormSubmission_GetByForm (entries list, newest first) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_DynamicFormSubmission_GetByForm]
    @FormId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  s.[SubmissionId], s.[FormId], s.[SubmittedBy],
            u.[USERNAME] AS [SubmittedByName],
            s.[SubmittedAt],
            (SELECT COUNT(*) FROM [dbo].[CMS_DynamicFormSubmissionValues] v
             WHERE v.[SubmissionId] = s.[SubmissionId]) AS [ValueCount]
    FROM [dbo].[CMS_DynamicFormSubmissions] s
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = s.[SubmittedBy]
    WHERE s.[FormId] = @FormId
    ORDER BY s.[SubmittedAt] DESC, s.[SubmissionId] DESC;
END
GO

/* ---- sp_CMS_DynamicFormSubmission_GetById (header + values) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_DynamicFormSubmission_GetById]
    @SubmissionId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT  s.[SubmissionId], s.[FormId], s.[SubmittedBy],
            u.[USERNAME] AS [SubmittedByName],
            s.[SubmittedAt]
    FROM [dbo].[CMS_DynamicFormSubmissions] s
    LEFT JOIN [dbo].[USERS] u ON u.[USERID] = s.[SubmittedBy]
    WHERE s.[SubmissionId] = @SubmissionId;

    SELECT  [FieldKey], [ValueJson]
    FROM [dbo].[CMS_DynamicFormSubmissionValues]
    WHERE [SubmissionId] = @SubmissionId;
END
GO

/* ---- sp_CMS_DynamicFormSubmission_Delete (values cascade) ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_DynamicFormSubmission_Delete]
    @SubmissionId INT,
    @PerformedBy INT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy])
    VALUES ('CMS_DynamicFormSubmissions', CAST(@SubmissionId AS VARCHAR(50)), 'DELETE', @PerformedBy);

    DELETE FROM [dbo].[CMS_DynamicFormSubmissions]
    WHERE [SubmissionId] = @SubmissionId;
END
GO

/* ---- sp_CMS_DynamicFormSubmission_GetFieldValues ----
   Raw stored values of one field across a form's entries. Powers the
   lookup upgrade: a lookup can offer values actually submitted before,
   instead of only the source field's configured options. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_DynamicFormSubmission_GetFieldValues]
    @FormId INT,
    @FieldKey VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT v.[ValueJson]
    FROM [dbo].[CMS_DynamicFormSubmissionValues] v
    INNER JOIN [dbo].[CMS_DynamicFormSubmissions] s
        ON s.[SubmissionId] = v.[SubmissionId]
    WHERE s.[FormId] = @FormId
      AND v.[FieldKey] = @FieldKey
      AND v.[ValueJson] IS NOT NULL;
END
GO
