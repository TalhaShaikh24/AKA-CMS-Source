#!/usr/bin/env python3
"""Sprint 9 tests: master-data lookups, workflow configuration (admin),
reporting/dashboard aggregates.

Covers: generic lookup endpoint for all 9 seeded types (incl. read-only
workflow-states and HIS facilities); unknown type 400; workflow states /
transitions listing; admin-only transition create (201), invalid states
(400), duplicates (400), enable/disable with RowVersion (204/409/404);
report aggregates consistent with API-created data (case/screening/
helpline/follow-up), date + unit filters, 401/403 gating, audit rows for
workflow-config writes. Existing CO-HIS tables are NOT touched.
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

# ---------- setup ----------
admin = login("admin", "Dev@Admin#2026")
check("admin login", bool(admin))

s, vu = api("POST", "/api/users", admin,
            {"username": f"viewer9_{RUNID}", "password": "Viewer@1234", "unitCode": 1})
viewer = login(f"viewer9_{RUNID}", "Viewer@1234")
check("viewer login (no new permissions)", bool(viewer))

# CO-HIS baseline taken after test-user creation (creating a user
# legitimately writes to the pre-existing USERS table — sprint 0 pattern).
cohis_before = sql("SELECT SUM(c) FROM (SELECT COUNT(*) c FROM USERS UNION ALL "
                   "SELECT COUNT(*) FROM ROLES UNION ALL SELECT COUNT(*) FROM PAT_ENCTR) t;")

# ---------- master-data lookups ----------
s, b = api("GET", "/api/lookups/crisis-types", admin)
codes = [(i or {}).get("code") for i in (b or [])]
check("lookups: crisis-types 6 seeded rows",
      s == 200 and len(b or []) == 6 and "SUI" in codes, f"status={s} n={len(b or [])}")
check("lookups: crisis-type carries default severity",
      any((i or {}).get("extra") in ("CRITICAL", "HIGH") for i in (b or [])))

s, b = api("GET", "/api/lookups/psych-modalities", admin)
check("lookups: psych-modalities 7 seeded rows",
      s == 200 and len(b or []) == 7, f"status={s} n={len(b or [])}")

s, b = api("GET", "/api/lookups/medications", admin)
check("lookups: medications 9 dictionary rows",
      s == 200 and len(b or []) == 9, f"status={s} n={len(b or [])}")

s, b = api("GET", "/api/lookups/risk-bands", admin)
check("lookups: risk-bands 9 rows with tool code",
      s == 200 and len(b or []) == 9 and all((i or {}).get("extra") for i in (b or [])),
      f"status={s} n={len(b or [])}")

s, b = api("GET", "/api/lookups/screening-tools", admin)
tcodes = [(i or {}).get("code") for i in (b or [])]
check("lookups: screening-tools PHQ9+GAD7",
      s == 200 and set(tcodes) == {"PHQ9", "GAD7"}, f"status={s} {tcodes}")

s, b = api("GET", "/api/lookups/case-sources", admin)
check("lookups: case-sources 8 rows",
      s == 200 and len(b or []) == 8, f"status={s} n={len(b or [])}")

s, b = api("GET", "/api/lookups/followup-types", admin)
fcodes = [(i or {}).get("code") for i in (b or [])]
check("lookups: followup-types 3 rows",
      s == 200 and set(fcodes) == {"SCHEDULED", "QUARTERLY_RESCREEN", "RE_ENGAGEMENT"},
      f"status={s} {fcodes}")

s, b = api("GET", "/api/lookups/workflow-states", admin)
scodes = [(i or {}).get("code") for i in (b or [])]
check("lookups: workflow-states 13 rows incl INTAKE",
      s == 200 and len(b or []) == 13 and "INTAKE" in scodes,
      f"status={s} n={len(b or [])}")

s, b = api("GET", "/api/lookups/facilities", admin)
check("lookups: facilities (HIS units) 200 + array",
      s == 200 and isinstance(b, list), f"status={s} n={len(b or []) if isinstance(b, list) else '?'}")

s, _ = api("GET", "/api/lookups/no-such-type", admin)
check("400: unknown lookup type", s == 400, f"status={s}")
s, _ = api("GET", "/api/lookups/crisis-types")
check("401: lookups without token", s == 401, f"status={s}")
s, _ = api("GET", "/api/lookups/crisis-types", viewer)
check("403: viewer denied lookups", s == 403, f"status={s}")

# ---------- workflow configuration ----------
s, b = api("GET", "/api/workflow/states", admin)
intake = next((x for x in (b or []) if x.get("stateCode") == "INTAKE"), {})
check("workflow: 13 states listed",
      s == 200 and len(b or []) == 13 and intake.get("isInitial") is True,
      f"status={s} n={len(b or [])}")

s, b = api("GET", "/api/workflow/transitions", admin)
trans = b or []
check("workflow: 22+ transitions listed with rowVersion",
      s == 200 and len(trans) >= 22 and all(t.get("rowVersion") for t in trans),
      f"status={s} n={len(trans)}")

s, _ = api("GET", "/api/workflow/states", viewer)
check("403: viewer denied workflow states", s == 403, f"status={s}")
s, _ = api("GET", "/api/workflow/transitions", viewer)
check("403: viewer denied workflow transitions", s == 403, f"status={s}")

ACTION = f"S9T{RUNID}"
s, created = api("POST", "/api/workflow/transitions", admin,
    {"fromState": "INTAKE", "actionCode": ACTION, "actionName": "Sprint9 test hop",
     "toState": "TRIAGE", "requiredPermissionName": "Cases:Write", "sortOrder": 99})
new_id = (created or {}).get("transitionId")
check("201: transition created (admin)", s == 201 and bool(new_id),
      f"status={s} id={new_id}")
new_rv = (created or {}).get("rowVersion")

s, b = api("GET", "/api/workflow/transitions", admin)
mine = [t for t in (b or []) if t.get("actionCode") == ACTION]
check("created transition visible in listing",
      len(mine) == 1 and mine[0].get("isActive") is True)

s, _ = api("POST", "/api/workflow/transitions", admin,
    {"fromState": "NOPE", "actionCode": f"{ACTION}X", "actionName": "x",
     "toState": "TRIAGE", "sortOrder": 0})
check("400: create with unknown from-state", s == 400, f"status={s}")
s, _ = api("POST", "/api/workflow/transitions", admin,
    {"fromState": "INTAKE", "actionCode": f"{ACTION}Y", "actionName": "x",
     "toState": "NOPE", "sortOrder": 0})
check("400: create with unknown to-state", s == 400, f"status={s}")
s, _ = api("POST", "/api/workflow/transitions", admin,
    {"fromState": "INTAKE", "actionCode": ACTION, "actionName": "dup",
     "toState": "TRIAGE", "sortOrder": 0})
check("400: duplicate from+action rejected", s == 400, f"status={s}")
s, _ = api("POST", "/api/workflow/transitions", admin,
    {"fromState": "INTAKE", "actionCode": "", "actionName": "x",
     "toState": "TRIAGE", "sortOrder": 0})
check("400: empty actionCode rejected", s == 400, f"status={s}")

s, _ = api("PATCH", f"/api/workflow/transitions/{new_id}", admin,
           {"isActive": False, "rowVersion": new_rv})
check("204: transition disabled", s == 204, f"status={s}")
s, b = api("GET", "/api/workflow/transitions", admin)
mine = [t for t in (b or []) if t.get("actionCode") == ACTION][0]
check("disabled transition shows isActive=false", mine.get("isActive") is False)
fresh_rv = mine.get("rowVersion")

s, _ = api("PATCH", f"/api/workflow/transitions/{new_id}", admin,
           {"isActive": True, "rowVersion": "AAAAAAAAAAA="})
check("409: stale rowVersion on enable", s == 409, f"status={s}")

s, _ = api("PATCH", f"/api/workflow/transitions/{new_id}", admin,
           {"isActive": True, "rowVersion": fresh_rv})
check("204: transition re-enabled", s == 204, f"status={s}")

s, _ = api("PATCH", "/api/workflow/transitions/999999", admin,
           {"isActive": False, "rowVersion": "AAAAAAAAAAA="})
check("404: set-active on unknown transition", s == 404, f"status={s}")

s, _ = api("POST", "/api/workflow/transitions", viewer,
    {"fromState": "INTAKE", "actionCode": f"{ACTION}Z", "actionName": "x",
     "toState": "TRIAGE", "sortOrder": 0})
check("403: viewer denied transition create", s == 403, f"status={s}")
s, _ = api("POST", "/api/workflow/transitions", body=
    {"fromState": "INTAKE", "actionCode": f"{ACTION}W", "actionName": "x",
     "toState": "TRIAGE", "sortOrder": 0})
check("401: transition create without token", s == 401, f"status={s}")

# ---------- reports ----------
s, b = api("POST", "/api/patients/members", admin,
           {"fullName": f"Sprint9 Report Patient {RUNID}", "gender": "F",
            "mrNo": f"MR-S9-{RUNID}"})
member_id = (b or {}).get("memberId")
s, b = api("POST", "/api/cases", admin,
           {"communityMemberId": member_id, "sourceType": "HealthFacility",
            "priorityLevel": "High", "notes": "Sprint9 report case"})
case_id = (b or {}).get("caseId")
check("setup: report case created", s == 201 and bool(case_id), f"caseId={case_id}")

def total(rows, key):
    return sum((r or {}).get(key, 0) for r in (rows or []))

s, b = api("GET", "/api/reports/case-summary", admin)
by_state, by_band = (b or {}).get("byState") or [], (b or {}).get("byRiskBand") or []
ts, tb = total(by_state, "caseCount"), total(by_band, "caseCount")
intake_n = next((r.get("caseCount", 0) for r in by_state if r.get("stateCode") == "INTAKE"), 0)
check("report: case-summary buckets balance + INTAKE>=1",
      s == 200 and ts == tb and ts >= 1 and intake_n >= 1,
      f"status={s} byState={ts} byBand={tb} intake={intake_n}")

s, f = api("GET", "/api/reports/case-summary?from=2020-01-01T00:00:00&to=2030-01-01T00:00:00", admin)
s2, f2 = api("GET", "/api/reports/case-summary?from=2030-01-01T00:00:00&to=2031-01-01T00:00:00", admin)
wide = total((f or {}).get("byState"), "caseCount")
narrow = total((f2 or {}).get("byState"), "caseCount")
check("report: case-summary date filter (wide=same, future=0)",
      wide == ts and narrow == 0, f"wide={wide} narrow={narrow}")

s, f = api("GET", "/api/reports/case-summary?unitCode=99999", admin)
check("report: case-summary unknown unit -> 0",
      s == 200 and total((f or {}).get("byState"), "caseCount") == 0, f"status={s}")

s, _ = api("POST", "/api/screenings/submit", admin,
           {"caseId": case_id, "toolCode": "PHQ9",
            "itemScores": [1, 1, 1, 1, 1, 1, 1, 1, 1]})
check("setup: PHQ9 screening submitted (raw=9)", s == 201, f"status={s}")

s, b = api("GET", "/api/reports/screening-summary", admin)
tools = (b or {}).get("tools") or []
phq9 = next((t for t in tools if t.get("toolCode") == "PHQ9"), {})
dist = [d for d in ((b or {}).get("riskDistribution") or []) if d.get("toolCode") == "PHQ9"]
exp = sql("SELECT COUNT(*), MIN(RawScore), MAX(RawScore) FROM CMS_Screenings WHERE ToolCode='PHQ9';")
ec, emin, emax = [x.strip() for x in exp.split()]
check("report: screening-summary PHQ9 stats match DB",
      s == 200 and str(phq9.get("screeningCount")) == ec
      and str(phq9.get("minScore")) == emin and str(phq9.get("maxScore")) == emax
      and sum(d.get("screeningCount", 0) for d in dist) == phq9.get("screeningCount"),
      f"status={s} api={phq9} db=({ec},{emin},{emax})")

s, b = api("GET", "/api/reports/screening-summary?toolCode=GAD7", admin)
tools = (b or {}).get("tools") or []
check("report: screening-summary toolCode filter (GAD7 only)",
      s == 200 and len(tools) == 1 and tools[0].get("toolCode") == "GAD7",
      f"status={s} n={len(tools)}")

s, _ = api("POST", "/api/helpline/calls", admin,
    {"callerName": "Sprint9 Caller", "callerPhone": "03001112222", "caseId": case_id,
     "indicators": {"suicidalIntent": False, "selfHarmRisk": False, "psychosis": False,
                    "panicAttack": False, "substanceCrisis": False, "otherAcute": False},
     "callNotes": "General info request."})
check("setup: general helpline call logged", s == 201, f"status={s}")

s, b = api("GET", "/api/reports/helpline-summary", admin)
by_type = {(r or {}).get("label"): (r or {}).get("count", 0)
           for r in ((b or {}).get("byType") or [])}
check("report: helpline-summary GENERAL>=1",
      s == 200 and by_type.get("GENERAL", 0) >= 1, f"status={s} {by_type}")

s, b = api("GET", "/api/reports/helpline-summary?from=2030-01-01T00:00:00&to=2031-01-01T00:00:00", admin)
check("report: helpline-summary future filter -> 0",
      s == 200 and sum((r or {}).get("count", 0) for r in ((b or {}).get("byType") or [])) == 0,
      f"status={s}")

# walk the case to IN_TREATMENT so a follow-up can be scheduled
def transition(cid, action, rv, assign=None):
    return api("POST", f"/api/cases/{cid}/transitions", admin,
               {"action": action, "comment": "sprint9", "assignedToUserId": assign,
                "rowVersion": rv})
s, b = api("GET", f"/api/cases/{case_id}", admin)
rv = (b or {}).get("rowVersion")
for action, assign in [("SubmitScreening", None), ("CompleteRiskAssessment", None),
                       ("AssignCaseManager", 1), ("BeginIntervention", None),
                       ("SendReferral", None), ("AcceptReferral", None)]:
    s, t = transition(case_id, action, rv, assign)
    rv = (t or {}).get("rowVersion")
check("setup: case walked to IN_TREATMENT",
      (api("GET", f"/api/cases/{case_id}", admin)[1] or {}).get("status") == "IN_TREATMENT")

d = (datetime.now(timezone.utc) + timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%S")
s, b = api("POST", "/api/follow-ups/schedule", admin,
           {"caseId": case_id, "scheduledDate": d, "followUpType": "SCHEDULED"})
fu = ((b or {}).get("followUp") or {})
check("setup: follow-up scheduled", s == 201 and bool(fu.get("followUpId")),
      f"status={s}")

s, b = api("GET", "/api/reports/followup-compliance", admin)
stats = {(r or {}).get("label"): (r or {}).get("count", 0)
         for r in ((b or {}).get("statuses") or [])}
check("report: followup-compliance SCHEDULED>=1",
      s == 200 and stats.get("SCHEDULED", 0) >= 1, f"status={s} {stats}")

s, _ = api("POST", f"/api/follow-ups/{fu.get('followUpId')}/outcome", admin,
           {"outcome": "COMPLETED", "outcomeNotes": "Attended",
            "rowVersion": fu.get("rowVersion")})
check("setup: follow-up outcome COMPLETED", s == 200, f"status={s}")
s, b = api("GET", "/api/reports/followup-compliance", admin)
stats = {(r or {}).get("label"): (r or {}).get("count", 0)
         for r in ((b or {}).get("statuses") or [])}
check("report: followup-compliance COMPLETED>=1",
      s == 200 and stats.get("COMPLETED", 0) >= 1, f"status={s} {stats}")

s, b = api("GET", "/api/reports/workload", admin)
entries = (b or {}).get("entries") or []
admin_id = int(sql("SELECT USERID FROM USERS WHERE USERNAME='admin';"))
mine = next((e for e in entries if e.get("assignedToUserId") == admin_id), {})
check("report: workload shows admin open cases>=1",
      s == 200 and mine.get("openCaseCount", 0) >= 1,
      f"status={s} entries={len(entries)}")

s, b = api("GET", "/api/reports/workload?unitCode=99999", admin)
check("report: workload unknown unit -> empty",
      s == 200 and len((b or {}).get("entries") or []) == 0, f"status={s}")

s, _ = api("GET", "/api/reports/case-summary")
check("401: reports without token", s == 401, f"status={s}")
s, _ = api("GET", "/api/reports/workload", viewer)
check("403: viewer denied reports", s == 403, f"status={s}")

# ---------- audit + CO-HIS integrity ----------
audit_n = sql("SELECT COUNT(*) FROM CMS_AuditLogs WHERE TableName='CMS_WorkflowTransitions' "
              f"AND RecordId='{new_id}';")
check("audit rows for transition create+setActive", audit_n.isdigit() and int(audit_n) >= 2,
      f"rows={audit_n}")

# cleanup: remove the test-created transition so later regression runs
# see the pristine 22-transition workflow graph again
sql(f"DELETE FROM CMS_WorkflowTransitions WHERE ActionCode='{ACTION}';")
check("cleanup: test transition removed",
      sql(f"SELECT COUNT(*) FROM CMS_WorkflowTransitions WHERE ActionCode='{ACTION}';") == "0")

cohis_after = sql("SELECT SUM(c) FROM (SELECT COUNT(*) c FROM USERS UNION ALL "
                  "SELECT COUNT(*) FROM ROLES UNION ALL SELECT COUNT(*) FROM PAT_ENCTR) t;")
check("CO-HIS existing tables untouched", cohis_after == cohis_before,
      f"before={cohis_before} after={cohis_after}")

print(f"\n{len(passed)} passed, {len(failed)} failed")
if failed:
    print("FAILED:", failed)
    raise SystemExit(1)
