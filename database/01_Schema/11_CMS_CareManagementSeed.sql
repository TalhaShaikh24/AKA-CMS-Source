/* ============================================================
   AKA-CMS - Sprint 5 seed data (11)
   Risk routing rules (from IMHP-CMS_Workflow.xlsx, cross-checked
   with the client wireframing PDF — the PDF is authoritative):

   HIGH risk (S18-S23-High):
     S18-High immediate response, S19-High crisis protocol,
     S20-High engage carers/frontline workers,
     S21-High refer to Psychologist & Psychiatrist once stabilized,
     S22-High high-risk monitoring (frequent contact, 2 months),
     S23-High flag dashboard high priority + alert supervisors,
     S25 referral sent.
   MODERATE risk (S18-S22-Mod):
     S18-Mod response within 24h, S19-Mod engage carers,
     S20-Mod refer to Psychologist + Psychiatrist,
     S21-Mod structured follow-up, S22-Mod supervisor oversight,
     S25 referral sent.
   LOW risk (S18-S22-Low):
     S18-Low response within 1 week, S19-Low engage carers,
     S20-Low psychosocial support & psychoeducation,
     S21-Low frontline follow-up (community/school/facility),
     S22-Low routine monitoring & quarterly re-screen.

   Plus permission catalog entries 90014-90021 granted to the
   Administrator role.
   Safe to re-run (guarded by MERGE / NOT EXISTS).
   ============================================================ */
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/* ---- Risk routing rules ---- */
MERGE INTO [dbo].[CMS_RiskRoutingRules] AS t
USING (VALUES
    ('HIGH', 'High Risk', 1,
     'PSYCHOLOGIST,PSYCHIATRIST', 1,
     N'[{"stepCode":"S18-High","title":"Provide Immediate Response","status":"PENDING"},' +
     N'{"stepCode":"S19-High","title":"Activate Crisis Protocol","status":"PENDING"},' +
     N'{"stepCode":"S20-High","title":"Engage Carers and Frontline Workers","status":"PENDING"},' +
     N'{"stepCode":"S21-High","title":"Refer to Psychologist & Psychiatrist Once Stabilized","status":"PENDING"},' +
     N'{"stepCode":"S22-High","title":"High-Risk Monitoring (Frequent Contact, 2 Months)","status":"PENDING"},' +
     N'{"stepCode":"S23-High","title":"Flag Dashboard High Priority & Alert Case Supervisors","status":"PENDING"},' +
     N'{"stepCode":"S25","title":"Referral Sent","status":"PENDING"}]'),
    ('MODERATE', 'Moderate Risk', 24,
     'PSYCHOLOGIST,PSYCHIATRIST', 0,
     N'[{"stepCode":"S18-Mod","title":"Response Within 24 Hours","status":"PENDING"},' +
     N'{"stepCode":"S19-Mod","title":"Engage Carers and Frontline Workers","status":"PENDING"},' +
     N'{"stepCode":"S20-Mod","title":"Refer to Psychologist + Psychiatrist","status":"PENDING"},' +
     N'{"stepCode":"S21-Mod","title":"Structured Follow-Up","status":"PENDING"},' +
     N'{"stepCode":"S22-Mod","title":"Supervisor Oversight","status":"PENDING"},' +
     N'{"stepCode":"S25","title":"Referral Sent","status":"PENDING"}]'),
    ('LOW', 'Low Risk', 168,
     'PSYCHOSOCIAL', 0,
     N'[{"stepCode":"S18-Low","title":"Response Within 1 Week","status":"PENDING"},' +
     N'{"stepCode":"S19-Low","title":"Engage Carers and Frontline Workers","status":"PENDING"},' +
     N'{"stepCode":"S20-Low","title":"Psychosocial Support & Psychoeducation","status":"PENDING"},' +
     N'{"stepCode":"S21-Low","title":"Frontline Follow-Up (Community/School/Facility)","status":"PENDING"},' +
     N'{"stepCode":"S22-Low","title":"Routine Monitoring & Quarterly Re-screen","status":"PENDING"}]')
) AS s ([RiskCategory], [DisplayName], [SlaHours], [ReferralTargets],
        [RequiresSupervisorAlert], [CarePlanStepsJson])
ON t.[RiskCategory] = s.[RiskCategory]
WHEN MATCHED THEN
    UPDATE SET [DisplayName] = s.[DisplayName], [SlaHours] = s.[SlaHours],
               [ReferralTargets] = s.[ReferralTargets],
               [RequiresSupervisorAlert] = s.[RequiresSupervisorAlert],
               [CarePlanStepsJson] = s.[CarePlanStepsJson], [IsActive] = 1
WHEN NOT MATCHED THEN
    INSERT ([RiskCategory], [DisplayName], [SlaHours], [ReferralTargets],
            [RequiresSupervisorAlert], [CarePlanStepsJson], [IsActive])
    VALUES (s.[RiskCategory], s.[DisplayName], s.[SlaHours], s.[ReferralTargets],
            s.[RequiresSupervisorAlert], s.[CarePlanStepsJson], 1);
GO

/* ---- Permission catalog entries for care management (IDs >= 90000) ---- */
MERGE INTO [dbo].[AllCONTROLLERS] AS t
USING (VALUES
    (90014, 'CarePlans', 'Read'),
    (90015, 'CarePlans', 'Write'),
    (90016, 'Referrals', 'Read'),
    (90017, 'Referrals', 'Write'),
    (90018, 'CaseComments', 'Read'),
    (90019, 'CaseComments', 'Write'),
    (90020, 'AssignmentQueue', 'Read'),
    (90021, 'AssignmentQueue', 'Write')
) AS s ([ID], [CONTROLLERNAME], [ACTION])
ON t.[ID] = s.[ID]
WHEN NOT MATCHED THEN
    INSERT ([ID], [CONTROLLERNAME], [RETURNTYPE], [ATTRIBUTES], [ACTION])
    VALUES (s.[ID], s.[CONTROLLERNAME], NULL, NULL, s.[ACTION]);
GO

/* Administrator role -> care-management permissions (guarded MAX(ID)+1 surrogate) */
INSERT INTO [dbo].[ROLESACTIONMAPPING]
    ([CONTROLLERID], [ROLEID], [ID], [ACTIVE], [CREATEDBY], [CREATEDDATE], [IPADDRESS])
SELECT s.[ControllerId], 1,
       (SELECT ISNULL(MAX([ID]), 0) FROM [dbo].[ROLESACTIONMAPPING]) + s.[RowNum],
       1, 'seed', SYSUTCDATETIME(), '127.0.0.1'
FROM (VALUES (90014, 1), (90015, 2), (90016, 3), (90017, 4),
             (90018, 5), (90019, 6), (90020, 7), (90021, 8)) AS s ([ControllerId], [RowNum])
WHERE NOT EXISTS (
    SELECT 1 FROM [dbo].[ROLESACTIONMAPPING] m
    WHERE m.[CONTROLLERID] = s.[ControllerId] AND m.[ROLEID] = 1
);
GO
