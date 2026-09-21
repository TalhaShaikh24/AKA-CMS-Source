/* ============================================================
   AKA-CMS — Sprint 3 seed data (07)
   Workflow states and transitions derived from Figure 3 of the
   client wireframing PDF (IMHP - End-to-End Clinical & Case
   Management Workflow), verified against the flowchart image.

   Permission catalog additions: 90009 Cases:Read, 90010 Cases:Write,
   90011 Cases:Close (supervisor-gated closure actions).
   Safe to re-run (guarded by MERGE / NOT EXISTS).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- Workflow states ---- */
MERGE INTO [dbo].[CMS_WorkflowStates] AS t
USING (VALUES
    ('INTAKE',          'Case Intake & Registration',        'Entry, screening and CMS registration (S1-S5)', 1, 0, 10),
    ('NO_CONSENT',      'No Consent - Re-engagement',        'Consent not obtained; psychoeducation and re-engagement (S5a-S5d)', 0, 0, 20),
    ('RISK_ASSESSMENT', 'Risk Assessment',                   'Risk assessment and emergency check (S6-S7)', 0, 0, 30),
    ('EMERGENCY',       'Emergency / Crisis Management',     'Crisis protocol active (S7a-S7i)', 0, 0, 40),
    ('TRIAGE',          'Risk Stratification & Review',      'Auto-scoring, risk stratification and supervisor review (S14-S16)', 0, 0, 50),
    ('ASSIGNED',        'Case Manager Assigned',             'Case manager assigned (S17)', 0, 0, 60),
    ('INTERVENTION',    'Risk-based Intervention',           'High/Moderate/Low risk intervention tracks (S18-S23)', 0, 0, 70),
    ('REFERRAL_SENT',   'Referral Sent',                     'Referral sent, awaiting acceptance (S25-S26)', 0, 0, 80),
    ('IN_TREATMENT',    'Clinical Workflow / Treatment',     'Treatment plan and interventions (S27-S31)', 0, 0, 90),
    ('FOLLOW_UP',       'Scheduled Follow-ups',              'Follow-up visits and care plan continuation (S32-S34)', 0, 0, 100),
    ('LTFU',            'Lost to Follow-up',                 'Marked LTFU; supervisor alert and re-engagement (S33b-S33d)', 0, 0, 110),
    ('MONITORING',      'Ongoing Community Monitoring',      'Community-based monitoring and supervision (S35-S38)', 0, 0, 120),
    ('CLOSED',          'Case Closed',                       'Formally closed by clinical supervisor', 0, 1, 130)
) AS s ([StateCode], [StateName], [Description], [IsInitial], [IsTerminal], [SortOrder])
ON t.[StateCode] = s.[StateCode]
WHEN MATCHED THEN
    UPDATE SET [StateName] = s.[StateName], [Description] = s.[Description],
               [IsInitial] = s.[IsInitial], [IsTerminal] = s.[IsTerminal], [SortOrder] = s.[SortOrder]
WHEN NOT MATCHED THEN
    INSERT ([StateCode], [StateName], [Description], [IsInitial], [IsTerminal], [SortOrder])
    VALUES (s.[StateCode], s.[StateName], s.[Description], s.[IsInitial], s.[IsTerminal], s.[SortOrder]);
GO

/* ---- Workflow transitions (FromState, ActionCode, ToState) ---- */
MERGE INTO [dbo].[CMS_WorkflowTransitions] AS t
USING (VALUES
    ('INTAKE',          'SubmitScreening',       'Submit Screening',        'RISK_ASSESSMENT', 'Cases:Write', 10),
    ('INTAKE',          'MarkNoConsent',         'Mark No Consent',         'NO_CONSENT',      'Cases:Write', 20),
    ('NO_CONSENT',      'ReEngage',              'Re-engage',               'INTAKE',          'Cases:Write', 10),
    ('RISK_ASSESSMENT', 'FlagEmergency',         'Flag Emergency',          'EMERGENCY',       'Cases:Write', 10),
    ('RISK_ASSESSMENT', 'CompleteRiskAssessment','Complete Risk Assessment','TRIAGE',          'Cases:Write', 20),
    ('TRIAGE',          'SubmitSupervisorReview','Submit Supervisor Review','TRIAGE',        'Supervision:Write', 5),
    ('EMERGENCY',       'Stabilize',             'Stabilize - Return to Clinical Pathway', 'TRIAGE', 'Cases:Write', 10),
    ('EMERGENCY',       'CloseEmergencyCare',    'Close Emergency Care',    'CLOSED',          'Cases:Close', 20),
    ('TRIAGE',          'AssignCaseManager',     'Assign Case Manager',     'ASSIGNED',        'Cases:Write', 10),
    ('ASSIGNED',        'BeginIntervention',     'Begin Intervention',      'INTERVENTION',    'Cases:Write', 10),
    ('INTERVENTION',    'SendReferral',          'Send Referral',           'REFERRAL_SENT',   'Cases:Write', 10),
    ('INTERVENTION',    'CloseCase',             'Close Case',              'CLOSED',          'Cases:Close', 90),
    ('REFERRAL_SENT',   'AcceptReferral',        'Accept Referral',         'IN_TREATMENT',    'Cases:Write', 10),
    ('REFERRAL_SENT',   'RerouteReferral',       'Re-route Referral',       'REFERRAL_SENT',   'Cases:Write', 20),
    ('IN_TREATMENT',    'ScheduleFollowUp',      'Schedule Follow-up',      'FOLLOW_UP',       'Cases:Write', 10),
    ('IN_TREATMENT',    'CloseCase',             'Close Case',              'CLOSED',          'Cases:Close', 90),
    ('FOLLOW_UP',       'ContinueFollowUp',      'Continue Follow-up',      'FOLLOW_UP',       'Cases:Write', 10),
    ('FOLLOW_UP',       'ResumeTreatment',       'Resume Treatment',        'IN_TREATMENT',    'Cases:Write', 25),
    ('FOLLOW_UP',       'RecordMissedVisit',     'Record Missed Visit',     'LTFU',            'Cases:Write', 20),
    ('FOLLOW_UP',       'CompleteTreatment',     'Complete Treatment',      'MONITORING',      'Cases:Write', 30),
    ('FOLLOW_UP',       'CloseCase',             'Close Case',              'CLOSED',          'Cases:Close', 90),
    ('LTFU',            'ReEngage',              'Re-engage',               'FOLLOW_UP',       'Cases:Write', 10),
    ('MONITORING',      'ReturnToCare',          'Return to Clinical Pathway', 'FOLLOW_UP',    'Cases:Write', 10),
    ('MONITORING',      'CloseCase',             'Close Case',              'CLOSED',          'Cases:Close', 90)
) AS s ([FromState], [ActionCode], [ActionName], [ToState], [RequiredPermissionName], [SortOrder])
ON t.[FromState] = s.[FromState] AND t.[ActionCode] = s.[ActionCode]
WHEN MATCHED THEN
    UPDATE SET [ActionName] = s.[ActionName], [ToState] = s.[ToState],
               [RequiredPermissionName] = s.[RequiredPermissionName], [SortOrder] = s.[SortOrder], [IsActive] = 1
WHEN NOT MATCHED THEN
    INSERT ([FromState], [ActionCode], [ActionName], [ToState], [RequiredPermissionName], [SortOrder], [IsActive])
    VALUES (s.[FromState], s.[ActionCode], s.[ActionName], s.[ToState], s.[RequiredPermissionName], s.[SortOrder], 1);
GO

/* ---- Permission catalog entries for cases (IDs >= 90000) ---- */
MERGE INTO [dbo].[AllCONTROLLERS] AS t
USING (VALUES
    (90009, 'Cases', 'Read'),
    (90010, 'Cases', 'Write'),
    (90011, 'Cases', 'Close')
) AS s ([ID], [CONTROLLERNAME], [ACTION])
ON t.[ID] = s.[ID]
WHEN NOT MATCHED THEN
    INSERT ([ID], [CONTROLLERNAME], [RETURNTYPE], [ATTRIBUTES], [ACTION])
    VALUES (s.[ID], s.[CONTROLLERNAME], NULL, NULL, s.[ACTION]);
GO

/* Administrator role -> case permissions (guarded MAX(ID)+1 surrogate) */
INSERT INTO [dbo].[ROLESACTIONMAPPING]
    ([CONTROLLERID], [ROLEID], [ID], [ACTIVE], [CREATEDBY], [CREATEDDATE], [IPADDRESS])
SELECT s.[ControllerId], 1,
       (SELECT ISNULL(MAX([ID]), 0) FROM [dbo].[ROLESACTIONMAPPING]) + s.[RowNum],
       1, 'seed', SYSUTCDATETIME(), '127.0.0.1'
FROM (VALUES (90009, 1), (90010, 2), (90011, 3)) AS s ([ControllerId], [RowNum])
WHERE NOT EXISTS (
    SELECT 1 FROM [dbo].[ROLESACTIONMAPPING] m
    WHERE m.[CONTROLLERID] = s.[ControllerId] AND m.[ROLEID] = 1 AND m.[ACTIVE] = 1
);
GO
