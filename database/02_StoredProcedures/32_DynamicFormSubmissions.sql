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
