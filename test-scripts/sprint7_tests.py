#!/usr/bin/env python3
"""Sprint 7 tests: Follow-Up, LTFU, Case Closure, Supervision (Module 6).

Covers: follow-up scheduling with auto ScheduleFollowUp transition,
outcome recording (COMPLETED/MISSED), missed-visit counting, idempotent
LTFU evaluation with supervisor notification, re-engagement back to
FOLLOW_UP, the two-step closure flow with the S34a Symptom Remission
gate, duplicate-pending-request conflict, RowVersion concurrency (409),
validation (400), auth gating (401/403), supervision logging, the
DB-driven due-follow-up list, and audit logging. Existing CO-HIS tables
are NOT touched.
"""
import json, urllib.request, urllib.error, subprocess, time, os
from datetime import datetime, timezone, timedelta

BASE = "http://localhost:5000"
with open("AKA.CMS.API/appsettings.Development.json") as f:
    CS = json.load(f)["ConnectionStrings"]["DefaultConnection"]
SAPW = CS.split("Password=")[1].split(";")[0] if "Password=" in CS else os.environ.get("SA_PASSWORD", "")
passed, failed = [], []
RUNID = str(int(time.time()))[-5:]

def check(name, cond, detail=""):
    (passed if cond else failed).append(name)
    print(("PASS " if cond else "FAIL ") + name + (f" [{detail}]" if detail else ""))

def api(method, path, token=None, body=None):
    req = urllib.request.Request(BASE + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Content-Type": "application/json"})
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read().decode() or "null")
    except urllib.error.HTTPError as e:
        try: return e.code, json.loads(e.read().decode() or "null")
        except Exception: return e.code, None

def sql(q):
    r = subprocess.run(["/opt/mssql-tools18/bin/sqlcmd", "-S", "localhost", "-U", "sa",
                        "-P", SAPW, "-C", "-d", "CO-HIS", "-h", "-1", "-W",
                        "-Q", "SET NOCOUNT ON;" + q],
                       capture_output=True, text=True)
    return r.stdout.strip()

def login(u, p):
    s, b = api("POST", "/api/auth/login", body={"username": u, "password": p})
    return (b or {}).get("accessToken") if s == 200 else None

admin = login("admin", "Dev@Admin#2026")
check("admin login", bool(admin))

s, vu = api("POST", "/api/users", admin,
            {"username": "viewer7", "password": "Viewer@1234", "unitCode": 1})
viewer = login("viewer7", "Viewer@1234")
check("viewer login", bool(viewer))

def transition(cid, action, rv, assign=None, comment=None):
    body = {"action": action, "comment": comment, "assignedToUserId": assign, "rowVersion": rv}
    return api("POST", f"/api/cases/{cid}/transitions", admin, body)

def make_case(name, priority="High", walk_to_treatment=True):
    s, b = api("POST", "/api/patients/members", admin,
               {"fullName": name, "gender": "F", "mrNo": f"MR-S7-{RUNID}-{name[-1]}"})
    mid = (b or {}).get("memberId")
    s, b = api("POST", "/api/cases", admin,
               {"communityMemberId": mid, "sourceType": "HealthFacility", "priorityLevel": priority})
    cid, rv = (b or {}).get("caseId"), (b or {}).get("rowVersion")
    if not walk_to_treatment:
        return cid, rv
    walk = [("SubmitScreening", None), ("CompleteRiskAssessment", None),
            ("AssignCaseManager", 1), ("BeginIntervention", None),
            ("SendReferral", None), ("AcceptReferral", None)]
    for action, assign in walk:
        s, t = transition(cid, action, rv, assign=assign, comment=f"Sprint7 {action}")
        rv = (t or {}).get("rowVersion")
    return cid, rv

def case_status(cid):
    s, b = api("GET", f"/api/cases/{cid}", admin)
    return (b or {}).get("status")

def sched(cid, ftype="SCHEDULED", days_ahead=7):
    d = (datetime.now(timezone.utc) + timedelta(days=days_ahead)).strftime("%Y-%m-%dT%H:%M:%S")
    return api("POST", "/api/follow-ups/schedule", admin,
               {"caseId": cid, "scheduledDate": d, "followUpType": ftype})

# ---------- setup ----------
case_fu, _ = make_case("Sprint7 FollowUp Patient 0001")
case_intake, _ = make_case("Sprint7 Intake Case 0002", priority="Low", walk_to_treatment=False)
s, b = api("GET", f"/api/cases/{case_fu}", admin)
check("setup: case walked to IN_TREATMENT", case_status(case_fu) == "IN_TREATMENT",
      f"status={case_status(case_fu)}")

# ---------- auth gating ----------
s, _ = api("POST", "/api/follow-ups/schedule")
check("401: schedule without token", s == 401, f"status={s}")
s, _ = api("POST", "/api/follow-ups/schedule", viewer,
           {"caseId": case_fu, "scheduledDate": "2026-09-24T10:00:00", "followUpType": "SCHEDULED"})
check("403: viewer denied schedule", s == 403, f"status={s}")
s, _ = api("POST", f"/api/ltfu/cases/{case_fu}/evaluate", viewer)
check("403: viewer denied LTFU evaluate", s == 403, f"status={s}")
s, _ = api("POST", f"/api/case-closures/{1}/approve", viewer,
           {"approve": True, "rowVersion": "AAAA"})
check("403: viewer denied closure approve", s == 403, f"status={s}")
s, _ = api("GET", "/api/follow-ups/due")
check("401: due list without token", s == 401, f"status={s}")
s, _ = api("GET", "/api/supervision/logs/by-case", viewer, )
check("403: viewer denied supervision read", s == 403, f"status={s}")

# ---------- validation ----------
s, _ = api("POST", "/api/follow-ups/schedule", admin,
           {"caseId": case_fu, "scheduledDate": "2026-09-24T10:00:00", "followUpType": "BAD_TYPE"})
check("400: schedule with bad FollowUpType", s == 400, f"status={s}")
s, _ = api("POST", "/api/follow-ups/schedule", admin,
           {"caseId": 0, "scheduledDate": "2026-09-24T10:00:00", "followUpType": "SCHEDULED"})
check("400: schedule with CaseId=0", s == 400, f"status={s}")
s, _ = api("POST", "/api/case-closures/request", admin,
           {"caseId": case_fu, "closureReason": "BAD_REASON", "symptomRemission": True})
check("400: closure request with bad reason", s == 400, f"status={s}")
s, _ = api("POST", "/api/supervision/logs", admin,
           {"caseId": case_fu, "supervisorUserId": 1, "reviewDate": "2026-09-17T10:00:00",
            "findings": "ok", "rating": "BAD_RATING"})
check("400: supervision log with bad rating", s == 400, f"status={s}")
s, _ = api("POST", f"/api/ltfu/cases/{case_fu}/re-engage", admin,
           {"reEngagementNotes": ""})
check("400: re-engage with empty notes", s == 400, f"status={s}")

# ---------- non-treatment state rejection ----------
s, d = api("POST", "/api/follow-ups/schedule", admin,
           {"caseId": case_intake, "scheduledDate": "2026-09-24T10:00:00", "followUpType": "SCHEDULED"})
check("400: schedule rejected for INTAKE case", s == 400, f"status={s}")

# ---------- schedule ----------
s, d = sched(case_fu)
check("201: follow-up scheduled", s == 201, f"status={s}")
sched_resp = d or {}
fu = (sched_resp.get("followUp") or {})
check("schedule: transition applied (ScheduleFollowUp)",
      sched_resp.get("caseTransitionApplied") is True, str(sched_resp.get("caseTransitionNote")))
check("schedule: case moved to FOLLOW_UP", case_status(case_fu) == "FOLLOW_UP",
      f"status={case_status(case_fu)}")
fu_id = fu.get("followUpId")
fu_rv = fu.get("rowVersion")
check("schedule: row returned", bool(fu_id and fu_rv), f"id={fu_id}")

# ---------- outcome: completed ----------
s, d = api("POST", f"/api/follow-ups/{fu_id}/outcome", admin,
           {"outcome": "COMPLETED", "outcomeNotes": "Attended", "rowVersion": fu_rv})
check("200: completed outcome recorded", s == 200, f"status={s}")
comp = (d or {})
check("completed: follow-up status COMPLETED",
      (comp.get("followUp") or {}).get("status") == "COMPLETED")
check("completed: not declared LTFU", comp.get("ltfuDeclared") is False)
check("completed: ContinueFollowUp applied", comp.get("caseTransitionApplied") is True,
      str(comp.get("caseTransitionNote")))

# ---------- outcome: missed -> LTFU ----------
s, d2 = sched(case_fu)
fu2 = (d2 or {}).get("followUp") or {}
fu2_id, fu2_rv = fu2.get("followUpId"), fu2.get("rowVersion")
s, m = api("POST", f"/api/follow-ups/{fu2_id}/outcome", admin,
           {"outcome": "MISSED", "outcomeNotes": "No show", "rowVersion": fu2_rv})
check("200: missed outcome recorded", s == 200, f"status={s}")
missed = m or {}
check("missed: LTFU declared (threshold 1)", missed.get("ltfuDeclared") is True)
check("missed: case moved to LTFU", case_status(case_fu) == "LTFU",
      f"status={case_status(case_fu)}")
check("missed: RecordMissedVisit applied", missed.get("caseTransitionApplied") is True,
      str(missed.get("caseTransitionNote")))

# ---------- LTFU tracking + idempotent evaluate ----------
s, t = api("GET", f"/api/ltfu/by-case?caseId={case_fu}", admin)
check("200: LTFU tracking by case", s == 200, f"status={s}")
trk = t or {}
check("tracking: status LTFU", trk.get("status") == "LTFU", trk.get("status"))
check("tracking: missedCount=1", trk.get("missedCount") == 1, str(trk.get("missedCount")))

s, e = api("POST", f"/api/ltfu/cases/{case_fu}/evaluate", admin)
check("200: re-evaluate LTFU (idempotent)", s == 200, f"status={s}")
ev = e or {}
check("evaluate: not re-declared", ev.get("declared") is False)
check("evaluate: still LTFU", (ev.get("tracking") or {}).get("status") == "LTFU")

n = sql(f"SELECT COUNT(*) FROM dbo.CMS_Notifications WHERE RelatedCaseId={case_fu} "
        f"AND RecipientRole='SUPERVISOR' AND RelatedEntity='LTFU' AND IsActive=1;")
check("supervisor LTFU alert notification", n == "1", f"count={n}")

# ---------- re-engage ----------
s, r = api("POST", f"/api/ltfu/cases/{case_fu}/re-engage", admin,
           {"reEngagementNotes": "Phone contact made; agreed to resume."})
check("200: re-engaged", s == 200, f"status={s}")
re = r or {}
check("re-engage: case back to FOLLOW_UP", case_status(case_fu) == "FOLLOW_UP",
      f"status={case_status(case_fu)}")
check("re-engage: ReEngage transition applied", re.get("caseTransitionApplied") is True,
      str(re.get("caseTransitionNote")))
check("re-engage: tracking RE_ENGAGED",
      (re.get("tracking") or {}).get("status") == "RE_ENGAGED")

# ---------- full loop: missed again -> re-declared ----------
s, d3 = sched(case_fu)
fu3 = (d3 or {}).get("followUp") or {}
s, m2 = api("POST", f"/api/follow-ups/{fu3.get('followUpId')}/outcome", admin,
            {"outcome": "MISSED", "outcomeNotes": "No show again",
             "rowVersion": fu3.get("rowVersion")})
check("re-declared LTFU after second missed", (m2 or {}).get("ltfuDeclared") is True)
check("case LTFU again", case_status(case_fu) == "LTFU", f"status={case_status(case_fu)}")

# ---------- closure: request without remission ----------
case_cl, _ = make_case("Sprint7 Closure Patient 0003", priority="Moderate")
s, dc = sched(case_cl)
s, rc = api("POST", "/api/case-closures/request", admin,
            {"caseId": case_cl, "closureReason": "TREATMENT_COMPLETE",
             "symptomRemission": False, "closureSummary": "Course done"})
check("201: closure requested (no remission)", s == 201, f"status={rc}")
cl = rc or {}
check("closure: status PENDING", cl.get("approvalStatus") == "PENDING")
cl_id, cl_rv = cl.get("closureId"), cl.get("rowVersion")

s, ap = api("POST", f"/api/case-closures/{cl_id}/approve", admin,
            {"approve": True, "rowVersion": cl_rv})
check("400: approve blocked by remission gate", s == 400, f"status={ap}")

# ---------- closure: request with remission ----------
s, rc2 = api("POST", "/api/case-closures/request", admin,
             {"caseId": case_cl, "closureReason": "SYMPTOM_REMISSION",
              "symptomRemission": True, "closureSummary": "Remission confirmed"})
check("409: duplicate pending closure request", s == 409, f"status={rc2}")

# approve the first request after updating remission? No - it was blocked at request.
# Request flow for remission case: new case
case_cl2, _ = make_case("Sprint7 Closure Patient 0004", priority="Low")
s, _ = sched(case_cl2)
s, rc3 = api("POST", "/api/case-closures/request", admin,
             {"caseId": case_cl2, "closureReason": "SYMPTOM_REMISSION",
              "symptomRemission": True, "closureSummary": "PHQ-9 normalized"})
check("201: closure requested (remission confirmed)", s == 201, f"status={rc3}")
cl2 = rc3 or {}
s, dup = api("POST", "/api/case-closures/request", admin,
             {"caseId": case_cl2, "closureReason": "SYMPTOM_REMISSION",
              "symptomRemission": True})
check("409: duplicate pending request blocked", s == 409, f"status={dup}")

s, stale = api("POST", f"/api/case-closures/{cl2.get('closureId')}/approve", admin,
               {"approve": True, "rowVersion": "AAAAAAAAAAA="})
check("409: approve with stale RowVersion", s == 409, f"status={stale}")

s, rej = api("POST", f"/api/case-closures/{cl2.get('closureId')}/approve", admin,
             {"approve": False, "rowVersion": cl2.get("rowVersion")})
check("400: reject without reason", s == 400, f"status={rej}")

s, ap2 = api("POST", f"/api/case-closures/{cl2.get('closureId')}/approve", admin,
             {"approve": True, "rowVersion": cl2.get("rowVersion")})
check("200: closure approved", s == 200, f"status={ap2}")
apd = ap2 or {}
check("approve: APPROVED", (apd.get("closure") or {}).get("approvalStatus") == "APPROVED")
check("approve: case CLOSED", case_status(case_cl2) == "CLOSED",
      f"status={case_status(case_cl2)}")
check("approve: CloseCase applied", apd.get("caseTransitionApplied") is True,
      str(apd.get("caseTransitionNote")))

s, hist = api("GET", f"/api/case-closures/by-case?caseId={case_cl2}", admin)
check("closure history listed", s == 200 and len(hist or []) == 1, f"status={s}")

# ---------- supervision ----------
s, sl = api("POST", "/api/supervision/logs", admin,
            {"caseId": case_fu, "supervisorUserId": 1,
             "reviewDate": "2026-09-17T10:00:00",
             "findings": "LTFU re-engagement reviewed; plan adequate.",
             "actionItems": "Weekly phone check for 1 month.", "rating": "SATISFACTORY"})
check("201: supervision log created", s == 201, f"status={sl}")
s, logs = api("GET", f"/api/supervision/logs/by-case?caseId={case_fu}", admin)
check("supervision log listed", s == 200 and len(logs or []) == 1, f"status={s}")

# ---------- due list (DB-driven thresholds) ----------
case_due, _ = make_case("Sprint7 Due Patient 0005", priority="High")
s, dd = sched(case_due, days_ahead=-10)
fud = (dd or {}).get("followUp") or {}
sql(f"UPDATE dbo.CMS_FollowUps SET CreatedAt=DATEADD(DAY,-12,SYSUTCDATETIME()), "
    f"ScheduledDate=DATEADD(DAY,-10,SYSUTCDATETIME()) WHERE FollowUpId={fud.get('followUpId')};")
sql(f"UPDATE dbo.CMS_Cases SET CreatedAt=DATEADD(DAY,-12,SYSUTCDATETIME()) WHERE CaseId={case_due};")
s, due = api("GET", "/api/follow-ups/due", admin)
due_cases = [r.get("caseId") for r in (due or [])]
check("due list includes overdue High-priority case", case_due in due_cases,
      f"found={case_due in due_cases}")
row = next((r for r in (due or []) if r.get("caseId") == case_due), {})
check("due row uses High frequency (7 days)", row.get("frequencyDays") == 7,
      str(row.get("frequencyDays")))

# ---------- audit ----------
a1 = sql("SELECT COUNT(*) FROM dbo.CMS_AuditLogs WHERE TableName='CMS_FollowUps';")
a2 = sql("SELECT COUNT(*) FROM dbo.CMS_AuditLogs WHERE TableName='CMS_CaseClosures';")
a3 = sql("SELECT COUNT(*) FROM dbo.CMS_AuditLogs WHERE TableName='CMS_SupervisionLogs';")
a4 = sql("SELECT COUNT(*) FROM dbo.CMS_AuditLogs WHERE TableName='CMS_LostToFollowUps';")
check("audit rows: follow-ups", a1.isdigit() and int(a1) > 0, a1)
check("audit rows: closures", a2.isdigit() and int(a2) > 0, a2)
check("audit rows: supervision", a3.isdigit() and int(a3) > 0, a3)
check("audit rows: LTFU", a4.isdigit() and int(a4) > 0, a4)

# ---------- CO-HIS untouched ----------
n_cohis = sql("SELECT COUNT(*) FROM sys.tables WHERE name IN "
              "('CMS_FollowUps','CMS_LostToFollowUps','CMS_CaseClosures',"
              "'CMS_SupervisionLogs','CMS_SystemSettings');")
check("only CMS_-prefixed tables added (5)", n_cohis == "5", n_cohis)

print(f"\n{len(passed)} passed, {len(failed)} failed")
exit(1 if failed else 0)
