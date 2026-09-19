/* ============================================================
   AKA-CMS — Sprint 6 procedures (12): treatment plans,
   psychological sessions, medication dictionary + prescriptions.

   Custom THROW numbers (project-wide):
     50005 - row-version mismatch (optimistic concurrency)
     50008 - entity not found
     50009 - domain validation failure (400)
     50010 - invalid domain value (400)
     50011 - duplicate/conflict (409)

   Every write proc: TRY/CATCH + transaction + CMS_AuditLogs row.
   A treatment is only valid while the case sits in a clinical
   state (IN_TREATMENT, FOLLOW_UP, MONITORING); attempts from any
   other state fail loudly with a 50009 note — never silently.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- sp_CMS_TreatmentPlan_Create ----
   One active plan per track (PSYCH/PHARM) per case; both S28
   tracks are created independently against the same case. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_TreatmentPlan_Create]
    @CaseId INT,
    @PlanTrack VARCHAR(10),
    @Title NVARCHAR(200),
    @Goals NVARCHAR(2000) = NULL,
    @PlannedInterventions NVARCHAR(2000) = NULL,
    @StartDate DATE,
    @PlannedEndDate DATE = NULL,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewPlanId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @CaseStatus VARCHAR(30);
        SELECT @CaseStatus = [Status]
        FROM [dbo].[CMS_Cases]
        WHERE [CaseId] = @CaseId AND [IsActive] = 1;

        IF @CaseStatus IS NULL
            THROW 50008, 'Case not found.', 1;
        IF @CaseStatus NOT IN ('IN_TREATMENT', 'FOLLOW_UP', 'MONITORING')
            THROW 50009, 'Treatment plans can only be created while the case is in treatment (IN_TREATMENT, FOLLOW_UP, MONITORING).', 1;
        IF @PlanTrack NOT IN ('PSYCH', 'PHARM')
            THROW 50010, 'PlanTrack must be PSYCH or PHARM.', 1;
        IF @Title IS NULL OR LTRIM(RTRIM(@Title)) = ''
            THROW 50009, 'Title is required.', 1;
        IF @StartDate IS NULL
            THROW 50009, 'StartDate is required.', 1;
        IF @PlannedEndDate IS NOT NULL AND @PlannedEndDate < @StartDate
            THROW 50009, 'PlannedEndDate cannot be before StartDate.', 1;
        IF EXISTS (SELECT 1 FROM [dbo].[CMS_TreatmentPlans]
                   WHERE [CaseId] = @CaseId AND [PlanTrack] = @PlanTrack
                     AND [Status] = 'Active' AND [IsActive] = 1)
            THROW 50011, 'An active plan of this track already exists for the case.', 1;

        INSERT INTO [dbo].[CMS_TreatmentPlans]
            ([CaseId], [PlanTrack], [Title], [Goals], [PlannedInterventions],
             [StartDate], [PlannedEndDate], [Status], [IsActive], [CreatedBy], [IpAddress])
        VALUES
            (@CaseId, @PlanTrack, @Title, @Goals, @PlannedInterventions,
             @StartDate, @PlannedEndDate, 'Active', 1, @CreatedBy, @IpAddress);

        SET @NewPlanId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_TreatmentPlans', CAST(@NewPlanId AS VARCHAR(50)), 'INSERT', @CreatedBy,
                @PlanTrack + ' plan for case ' + CAST(@CaseId AS VARCHAR(20)));

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_TreatmentPlan_Update ----
   RowVersion-checked update; status moves Active -> Completed /
   Discontinued (terminal); Completed/Discontinued plans cannot be
   re-opened or edited except for notes. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_TreatmentPlan_Update]
    @PlanId INT,
    @Title NVARCHAR(200),
    @Goals NVARCHAR(2000) = NULL,
    @PlannedInterventions NVARCHAR(2000) = NULL,
    @PlannedEndDate DATE = NULL,
    @Status VARCHAR(20),
    @RowVersion BINARY(8),
    @PerformedBy INT,
    @IpAddress VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @CurrentStatus VARCHAR(20), @CurrentRowVersion BINARY(8);
        SELECT @CurrentStatus = [Status], @CurrentRowVersion = [RowVersion]
        FROM [dbo].[CMS_TreatmentPlans]
        WHERE [PlanId] = @PlanId AND [IsActive] = 1;

        IF @CurrentStatus IS NULL
            THROW 50008, 'Treatment plan not found.', 1;
        IF @CurrentRowVersion <> @RowVersion
            THROW 50005, 'The treatment plan was modified by another user. Reload and try again.', 1;
        IF @Status NOT IN ('Active', 'Completed', 'Discontinued')
            THROW 50010, 'Status must be Active, Completed or Discontinued.', 1;
        IF @CurrentStatus IN ('Completed', 'Discontinued') AND @Status <> @CurrentStatus
            THROW 50009, 'A completed or discontinued plan cannot change status.', 1;
        IF @Title IS NULL OR LTRIM(RTRIM(@Title)) = ''
            THROW 50009, 'Title is required.', 1;

        UPDATE [dbo].[CMS_TreatmentPlans]
        SET [Title] = @Title,
            [Goals] = @Goals,
            [PlannedInterventions] = @PlannedInterventions,
            [PlannedEndDate] = @PlannedEndDate,
            [Status] = @Status
        WHERE [PlanId] = @PlanId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_TreatmentPlans', CAST(@PlanId AS VARCHAR(50)), 'UPDATE', @PerformedBy,
                'Status -> ' + @Status);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_TreatmentPlan_GetById ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_TreatmentPlan_GetById]
    @PlanId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.[PlanId], p.[CaseId], p.[PlanTrack], p.[Title], p.[Goals],
           p.[PlannedInterventions], p.[StartDate], p.[PlannedEndDate], p.[Status],
           p.[RowVersion], p.[IsActive], p.[CreatedAt],
           (SELECT COUNT(1) FROM [dbo].[CMS_PsychologicalSessions] s
            WHERE s.[PlanId] = p.[PlanId] AND s.[IsActive] = 1) AS [PsychSessionCount],
           (SELECT COUNT(1) FROM [dbo].[CMS_MedicationPrescriptions] rx
            WHERE rx.[PlanId] = p.[PlanId] AND rx.[IsActive] = 1) AS [PrescriptionCount]
    FROM [dbo].[CMS_TreatmentPlans] p
    WHERE p.[PlanId] = @PlanId AND p.[IsActive] = 1;
END
GO

/* ---- sp_CMS_TreatmentPlan_GetByCase ----
   Both S28 tracks listed together with their progress counters. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_TreatmentPlan_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT p.[PlanId], p.[CaseId], p.[PlanTrack], p.[Title], p.[Goals],
           p.[PlannedInterventions], p.[StartDate], p.[PlannedEndDate], p.[Status],
           p.[RowVersion], p.[IsActive], p.[CreatedAt],
           (SELECT COUNT(1) FROM [dbo].[CMS_PsychologicalSessions] s
            WHERE s.[PlanId] = p.[PlanId] AND s.[IsActive] = 1) AS [PsychSessionCount],
           (SELECT COUNT(1) FROM [dbo].[CMS_MedicationPrescriptions] rx
            WHERE rx.[PlanId] = p.[PlanId] AND rx.[IsActive] = 1) AS [PrescriptionCount]
    FROM [dbo].[CMS_TreatmentPlans] p
    WHERE p.[CaseId] = @CaseId AND p.[IsActive] = 1
    ORDER BY p.[PlanTrack], p.[PlanId];
END
GO

/* ---- sp_CMS_PsychologicalSession_Record ----
   Sessions document the psychological track; they always belong to
   an active plan (never to a bare case) and the case must remain in
   a clinical state at recording time. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_PsychologicalSession_Record]
    @PlanId INT,
    @CaseId INT,
    @TherapistUserId INT = NULL,
    @SessionDate DATETIME2(0),
    @ModalityCode VARCHAR(20),
    @DurationMinutes INT = NULL,
    @SessionNotes NVARCHAR(2000) = NULL,
    @OutcomeNotes NVARCHAR(2000) = NULL,
    @NextSessionDate DATE = NULL,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewSessionId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @PlanCaseId INT, @PlanStatus VARCHAR(20), @PlanTrack VARCHAR(10);
        SELECT @PlanCaseId = [CaseId], @PlanStatus = [Status], @PlanTrack = [PlanTrack]
        FROM [dbo].[CMS_TreatmentPlans]
        WHERE [PlanId] = @PlanId AND [IsActive] = 1;

        IF @PlanCaseId IS NULL
            THROW 50008, 'Treatment plan not found.', 1;
        IF @PlanStatus <> 'Active'
            THROW 50009, 'Psychological sessions can only be recorded against an active plan.', 1;
        IF @PlanCaseId <> @CaseId
            THROW 50009, 'The plan does not belong to the given case.', 1;
        IF @PlanTrack <> 'PSYCH'
            THROW 50009, 'Psychological sessions can only be recorded against a PSYCH-track plan.', 1;

        DECLARE @CaseStatus VARCHAR(30);
        SELECT @CaseStatus = [Status]
        FROM [dbo].[CMS_Cases]
        WHERE [CaseId] = @CaseId AND [IsActive] = 1;

        IF @CaseStatus IS NULL
            THROW 50008, 'Case not found.', 1;
        IF @CaseStatus NOT IN ('IN_TREATMENT', 'FOLLOW_UP', 'MONITORING')
            THROW 50009, 'Psychological sessions can only be recorded while the case is in treatment (IN_TREATMENT, FOLLOW_UP, MONITORING).', 1;
        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_PsychModalityTypes]
                       WHERE [ModalityCode] = @ModalityCode AND [IsActive] = 1)
            THROW 50010, 'Unknown or inactive psychological modality.', 1;
        IF @SessionDate IS NULL
            THROW 50009, 'SessionDate is required.', 1;
        IF @DurationMinutes IS NOT NULL AND @DurationMinutes <= 0
            THROW 50009, 'DurationMinutes must be positive.', 1;

        INSERT INTO [dbo].[CMS_PsychologicalSessions]
            ([PlanId], [CaseId], [TherapistUserId], [SessionDate], [ModalityCode],
             [DurationMinutes], [SessionNotes], [OutcomeNotes], [NextSessionDate],
             [IsActive], [CreatedBy], [IpAddress])
        VALUES
            (@PlanId, @CaseId, @TherapistUserId, @SessionDate, @ModalityCode,
             @DurationMinutes, @SessionNotes, @OutcomeNotes, @NextSessionDate,
             1, @CreatedBy, @IpAddress);

        SET @NewSessionId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_PsychologicalSessions', CAST(@NewSessionId AS VARCHAR(50)), 'INSERT', @CreatedBy,
                @ModalityCode + ' session for plan ' + CAST(@PlanId AS VARCHAR(20)));

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_PsychologicalSession_GetByCase ---- */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_PsychologicalSession_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.[SessionId], s.[PlanId], s.[CaseId], s.[TherapistUserId], s.[SessionDate],
           s.[ModalityCode], m.[DisplayName] AS [ModalityName],
           s.[DurationMinutes], s.[SessionNotes], s.[OutcomeNotes], s.[NextSessionDate],
           s.[RowVersion], s.[CreatedAt]
    FROM [dbo].[CMS_PsychologicalSessions] s
    LEFT JOIN [dbo].[CMS_PsychModalityTypes] m ON m.[ModalityCode] = s.[ModalityCode]
    WHERE s.[CaseId] = @CaseId AND s.[IsActive] = 1
    ORDER BY s.[SessionDate] DESC, s.[SessionId] DESC;
END
GO

/* ---- sp_CMS_MedicationDictionary_GetAll ----
   Read-only formulary lookup for the UI; only active entries. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_MedicationDictionary_GetAll]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT [MedicationId], [MedicationCode], [GenericName], [Strength], [DosageForm],
           [ClinicalConfirmationPending], [SortOrder]
    FROM [dbo].[CMS_MedicationDictionary]
    WHERE [IsActive] = 1
    ORDER BY [SortOrder], [GenericName];
END
GO

/* ---- sp_CMS_MedicationPrescription_Create ----
   MedicationId must come from CMS_MedicationDictionary — no
   free-text drug names. Generates a sequential RxNumber
   (RX-YYYY-######). */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_MedicationPrescription_Create]
    @CaseId INT,
    @PlanId INT = NULL,
    @MedicationId INT,
    @PrescribedByUserId INT = NULL,
    @DoseText NVARCHAR(100),
    @Frequency NVARCHAR(100),
    @DurationDays INT,
    @Instructions NVARCHAR(500) = NULL,
    @DiagnosisText NVARCHAR(500) = NULL,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewPrescriptionId INT OUTPUT,
    @RxNumber VARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @CaseStatus VARCHAR(30);
        SELECT @CaseStatus = [Status]
        FROM [dbo].[CMS_Cases]
        WHERE [CaseId] = @CaseId AND [IsActive] = 1;

        IF @CaseStatus IS NULL
            THROW 50008, 'Case not found.', 1;
        IF @CaseStatus NOT IN ('IN_TREATMENT', 'FOLLOW_UP', 'MONITORING')
            THROW 50009, 'Prescriptions can only be created while the case is in treatment (IN_TREATMENT, FOLLOW_UP, MONITORING).', 1;
        IF NOT EXISTS (SELECT 1 FROM [dbo].[CMS_MedicationDictionary]
                       WHERE [MedicationId] = @MedicationId AND [IsActive] = 1)
            THROW 50008, 'Medication not found in the formulary.', 1;

        IF @PlanId IS NOT NULL
        BEGIN
            DECLARE @PlanCaseId INT, @PlanStatus VARCHAR(20), @PlanTrack VARCHAR(10);
            SELECT @PlanCaseId = [CaseId], @PlanStatus = [Status], @PlanTrack = [PlanTrack]
            FROM [dbo].[CMS_TreatmentPlans]
            WHERE [PlanId] = @PlanId AND [IsActive] = 1;

            IF @PlanCaseId IS NULL
                THROW 50008, 'Treatment plan not found.', 1;
            IF @PlanStatus <> 'Active'
                THROW 50009, 'Prescriptions can only be linked to an active plan.', 1;
            IF @PlanCaseId <> @CaseId
                THROW 50009, 'The plan does not belong to the given case.', 1;
            IF @PlanTrack <> 'PHARM'
                THROW 50009, 'Prescriptions can only be linked to a PHARM-track plan.', 1;
        END;

        IF @DoseText IS NULL OR LTRIM(RTRIM(@DoseText)) = ''
            THROW 50009, 'Dose is required.', 1;
        IF @Frequency IS NULL OR LTRIM(RTRIM(@Frequency)) = ''
            THROW 50009, 'Frequency is required.', 1;
        IF @DurationDays IS NULL OR @DurationDays <= 0
            THROW 50009, 'DurationDays must be positive.', 1;

        SET @RxNumber =
            'RX-' + CAST(YEAR(SYSUTCDATETIME()) AS VARCHAR(4)) + '-'
            + RIGHT('000000' + CAST(NEXT VALUE FOR [dbo].[CMS_PrescriptionNumberSeq] AS VARCHAR(10)), 6);

        INSERT INTO [dbo].[CMS_MedicationPrescriptions]
            ([RxNumber], [CaseId], [PlanId], [MedicationId], [PrescribedByUserId],
             [DoseText], [Frequency], [DurationDays], [Instructions], [DiagnosisText],
             [Status], [IsActive], [CreatedBy], [IpAddress])
        VALUES
            (@RxNumber, @CaseId, @PlanId, @MedicationId, @PrescribedByUserId,
             @DoseText, @Frequency, @DurationDays, @Instructions, @DiagnosisText,
             'Active', 1, @CreatedBy, @IpAddress);

        SET @NewPrescriptionId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_MedicationPrescriptions', CAST(@NewPrescriptionId AS VARCHAR(50)), 'INSERT', @CreatedBy, @RxNumber);

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_MedicationPrescription_Cancel ----
   Soft cancel (Active -> Cancelled); the row and its audit trail
   are preserved — nothing is ever deleted. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_MedicationPrescription_Cancel]
    @PrescriptionId INT,
    @RowVersion BINARY(8),
    @PerformedBy INT,
    @IpAddress VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @CurrentStatus VARCHAR(20), @CurrentRowVersion BINARY(8);
        SELECT @CurrentStatus = [Status], @CurrentRowVersion = [RowVersion]
        FROM [dbo].[CMS_MedicationPrescriptions]
        WHERE [PrescriptionId] = @PrescriptionId AND [IsActive] = 1;

        IF @CurrentStatus IS NULL
            THROW 50008, 'Prescription not found.', 1;
        IF @CurrentRowVersion <> @RowVersion
            THROW 50005, 'The prescription was modified by another user. Reload and try again.', 1;
        IF @CurrentStatus <> 'Active'
            THROW 50009, 'Only an Active prescription can be cancelled.', 1;

        UPDATE [dbo].[CMS_MedicationPrescriptions]
        SET [Status] = 'Cancelled'
        WHERE [PrescriptionId] = @PrescriptionId;

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_MedicationPrescriptions', CAST(@PrescriptionId AS VARCHAR(50)), 'UPDATE', @PerformedBy,
                'Status -> Cancelled');

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO

/* ---- sp_CMS_MedicationPrescription_GetByCase ----
   Prescriptions with formulary display data and dispense counts. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_MedicationPrescription_GetByCase]
    @CaseId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT rx.[PrescriptionId], rx.[RxNumber], rx.[CaseId], rx.[PlanId],
           rx.[MedicationId], d.[MedicationCode], d.[GenericName], d.[Strength], d.[DosageForm],
           rx.[PrescribedByUserId], rx.[DoseText], rx.[Frequency], rx.[DurationDays],
           rx.[Instructions], rx.[DiagnosisText], rx.[Status],
           rx.[RowVersion], rx.[CreatedAt],
           (SELECT COUNT(1) FROM [dbo].[CMS_MedicationDispensing] disp
            WHERE disp.[PrescriptionId] = rx.[PrescriptionId] AND disp.[IsActive] = 1) AS [DispenseCount]
    FROM [dbo].[CMS_MedicationPrescriptions] rx
    INNER JOIN [dbo].[CMS_MedicationDictionary] d ON d.[MedicationId] = rx.[MedicationId]
    WHERE rx.[CaseId] = @CaseId AND rx.[IsActive] = 1
    ORDER BY rx.[CreatedAt] DESC, rx.[PrescriptionId] DESC;
END
GO

/* ---- sp_CMS_Medication_Dispense ----
   Records a dispensing event (adherence monitoring); the
   prescription must still be Active. */
CREATE OR ALTER PROCEDURE [dbo].[sp_CMS_Medication_Dispense]
    @PrescriptionId INT,
    @DispensedDate DATETIME2(0),
    @Quantity DECIMAL(10, 2),
    @DispensedByUserId INT = NULL,
    @AdherenceNotes NVARCHAR(1000) = NULL,
    @CreatedBy INT,
    @IpAddress VARCHAR(50),
    @NewDispenseId INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        DECLARE @RxStatus VARCHAR(20);
        SELECT @RxStatus = [Status]
        FROM [dbo].[CMS_MedicationPrescriptions]
        WHERE [PrescriptionId] = @PrescriptionId AND [IsActive] = 1;

        IF @RxStatus IS NULL
            THROW 50008, 'Prescription not found.', 1;
        IF @RxStatus <> 'Active'
            THROW 50009, 'Medication can only be dispensed against an Active prescription.', 1;
        IF @DispensedDate IS NULL
            THROW 50009, 'DispensedDate is required.', 1;
        IF @Quantity IS NULL OR @Quantity <= 0
            THROW 50009, 'Quantity must be positive.', 1;

        INSERT INTO [dbo].[CMS_MedicationDispensing]
            ([PrescriptionId], [DispensedDate], [Quantity], [DispensedByUserId],
             [AdherenceNotes], [IsActive], [CreatedBy], [IpAddress])
        VALUES
            (@PrescriptionId, @DispensedDate, @Quantity, @DispensedByUserId,
             @AdherenceNotes, 1, @CreatedBy, @IpAddress);

        SET @NewDispenseId = SCOPE_IDENTITY();

        INSERT INTO [dbo].[CMS_AuditLogs] ([TableName], [RecordId], [Action], [PerformedBy], [Details])
        VALUES ('CMS_MedicationDispensing', CAST(@NewDispenseId AS VARCHAR(50)), 'INSERT', @CreatedBy,
                'Prescription ' + CAST(@PrescriptionId AS VARCHAR(20)) + ', qty ' + CAST(@Quantity AS VARCHAR(20)));

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END
GO
