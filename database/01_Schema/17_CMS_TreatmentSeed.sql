/* ============================================================
   AKA-CMS — Sprint 6 seed (17).

   Psychological modalities: seeded from the standard WHO
   mhGAP-IG psychological interventions referenced by the
   wireframing logic (assessment, structured treatment planning,
   session documentation, outcome monitoring). IsClientSourced = 0
   on every row — pending clinical confirmation from the client.

   Medication formulary: seeded from the WHO mhGAP-IG essential
   psychotropic medicines list. ClinicalConfirmationPending = 1 on
   every row — pending clinical confirmation from the client
   before go-live.

   Permission catalog entries 90032-90037 (continuing the >= 90000
   sequence), granted to the Administrator role with the guarded
   MAX(ID)+1 surrogate pattern.
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- Psychological modality types (all pending clinical confirmation) ---- */
MERGE INTO [dbo].[CMS_PsychModalityTypes] AS t
USING (VALUES
    ('CBT',        N'Cognitive Behavioral Therapy', N'mhGAP-IG standard psychological intervention.', 0, 10),
    ('IPT',        N'Interpersonal Therapy',        N'mhGAP-IG standard psychological intervention.', 0, 20),
    ('PSYEDU',     N'Psychoeducation',              N'mhGAP-IG: information and education about the condition.', 0, 30),
    ('BEHACT',     N'Behavioural Activation',      N'mhGAP-IG standard psychological intervention.', 0, 40),
    ('PROBSOL',    N'Problem-Solving Therapy',     N'mhGAP-IG standard psychological intervention.', 0, 50),
    ('RELAX',      N'Relaxation Techniques',       N'mhGAP-IG standard psychological intervention.', 0, 60),
    ('SUPCOUNS',   N'Supportive Counselling',      N'mhGAP-IG standard psychological intervention.', 0, 70)
) AS s ([ModalityCode], [DisplayName], [Description], [IsClientSourced], [SortOrder])
ON t.[ModalityCode] = s.[ModalityCode]
WHEN MATCHED THEN
    UPDATE SET [DisplayName] = s.[DisplayName],
               [Description] = s.[Description],
               [IsClientSourced] = s.[IsClientSourced],
               [SortOrder] = s.[SortOrder],
               [IsActive] = 1
WHEN NOT MATCHED THEN
    INSERT ([ModalityCode], [DisplayName], [Description], [IsClientSourced], [SortOrder], [IsActive])
    VALUES (s.[ModalityCode], s.[DisplayName], s.[Description], s.[IsClientSourced], s.[SortOrder], 1);
GO

/* ---- Medication formulary (all pending clinical confirmation) ---- */
MERGE INTO [dbo].[CMS_MedicationDictionary] AS t
USING (VALUES
    ('FLX-20-CAP',  N'Fluoxetine',        N'20 mg',  N'Capsule', 1, 10),
    ('SRT-50-TAB',  N'Sertraline',        N'50 mg',  N'Tablet',  1, 20),
    ('AMI-25-TAB',  N'Amitriptyline',     N'25 mg',  N'Tablet',  1, 30),
    ('RIS-1-TAB',   N'Risperidone',       N'1 mg',   N'Tablet',  1, 40),
    ('RIS-2-TAB',   N'Risperidone',       N'2 mg',   N'Tablet',  1, 50),
    ('OLZ-5-TAB',   N'Olanzapine',        N'5 mg',   N'Tablet',  1, 60),
    ('DZP-5-TAB',   N'Diazepam',          N'5 mg',   N'Tablet',  1, 70),
    ('CBZ-200-TAB', N'Carbamazepine',     N'200 mg', N'Tablet',  1, 80),
    ('VAL-200-TAB', N'Sodium Valproate',  N'200 mg', N'Tablet',  1, 90)
) AS s ([MedicationCode], [GenericName], [Strength], [DosageForm], [ClinicalConfirmationPending], [SortOrder])
ON t.[MedicationCode] = s.[MedicationCode]
WHEN MATCHED THEN
    UPDATE SET [GenericName] = s.[GenericName],
               [Strength] = s.[Strength],
               [DosageForm] = s.[DosageForm],
               [ClinicalConfirmationPending] = s.[ClinicalConfirmationPending],
               [SortOrder] = s.[SortOrder],
               [IsActive] = 1
WHEN NOT MATCHED THEN
    INSERT ([MedicationCode], [GenericName], [Strength], [DosageForm],
            [ClinicalConfirmationPending], [SortOrder], [IsActive])
    VALUES (s.[MedicationCode], s.[GenericName], s.[Strength], s.[DosageForm],
            s.[ClinicalConfirmationPending], s.[SortOrder], 1);
GO

/* ---- Permission catalog entries for treatment modules (IDs >= 90000) ---- */
MERGE INTO [dbo].[AllCONTROLLERS] AS t
USING (VALUES
    (90032, 'TreatmentPlans', 'Read'),
    (90033, 'TreatmentPlans', 'Write'),
    (90034, 'PsychologicalSessions', 'Read'),
    (90035, 'PsychologicalSessions', 'Write'),
    (90036, 'Medications', 'Read'),
    (90037, 'Medications', 'Write')
) AS s ([ID], [CONTROLLERNAME], [ACTION])
ON t.[ID] = s.[ID]
WHEN NOT MATCHED THEN
    INSERT ([ID], [CONTROLLERNAME], [RETURNTYPE], [ATTRIBUTES], [ACTION])
    VALUES (s.[ID], s.[CONTROLLERNAME], NULL, NULL, s.[ACTION]);
GO

/* Administrator role -> treatment permissions.
   NOTE: granted through sp_CMS_Role_AssignPermission (idempotent),
   because this local dev database has a corrupt catalog name-index
   on ROLEACTIONMAPPING — ad-hoc INSERT ... dbo.ROLEACTIONMAPPING
   fails with Msg 208, while the existing proc resolves the table
   through its bound object-id. Local-environment quirk only; the
   client's real database is unaffected. */
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90032, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90033, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90034, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90035, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90036, @CreatedBy = 'seed', @PerformedBy = 1;
EXEC [dbo].[sp_CMS_Role_AssignPermission] @RoleId = 1, @ControllerActionId = 90037, @CreatedBy = 'seed', @PerformedBy = 1;
GO
