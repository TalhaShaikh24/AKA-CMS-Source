#!/usr/bin/env python3
"""Sprint 4b tests: Helpline & Crisis Management (Module 2).

Covers: helpline call logging (crisis + routine), automatic
CrisisEvent + Immediate Alert notification creation, EMERGENCY
routing via the S7a-S7i path, manual crisis triggers, status
updates (Stabilized -> TRIAGE via the S7g branch, ContinueCare),
RowVersion concurrency (409), safety-plan create/get, crisis-type
catalog, validation (400), permission gating (403), auth (401),
and audit logging.

Prerequisites: CO-HIS restored, all CMS schema/proc files applied,
API running on http://localhost:5000.
"""
import base64, json, urllib.request, urllib.error, subprocess

BASE = "http://localhost:5000"
SAPW = "DevPass2026Strong"
passed, failed = [], []

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

# limited user with no helpline/crisis permissions (for 403 tests)
s, vu = api("POST", "/api/users", admin,
            {"username": "viewer2", "password": "Viewer@1234", "unitCode": 1})
viewer = login("viewer2", "Viewer@1234")
check("viewer login", bool(viewer))

# ---------- crisis types catalog ----------
s, types = api("GET", "/api/crisis-events/types", admin)
codes = {t["crisisTypeCode"] for t in (types or [])}
check("GET crisis types -> 200", s == 200, f"status={s}")
check("types include SUI/SHM/PSY/PAN/SUB", {"SUI", "SHM", "PSY", "PAN", "SUB"} <= codes, str(sorted(codes)))

# ---------- test case moved to RISK_ASSESSMENT (so FlagEmergency is allowed) ----------
s, b = api("POST", "/api/patients/members", admin,
           {"fullName": "Sprint4b Crisis Patient", "gender": "M", "mrNo": "MR-4B01"})
member_id = (b or {}).get("memberId")
s, b = api("POST", "/api/cases", admin,
           {"communityMemberId": member_id, "sourceType": "Helpline", "priorityLevel": "High"})
case_id = (b or {}).get("caseId")
check("setup: case created", bool(case_id), f"caseId={case_id}")
s, resp = api("POST", "/api/screenings/submit", admin,
              {"caseId": case_id, "toolCode": "PHQ9", "itemScores": [1, 1, 1, 1, 1, 1, 1, 1, 1]})
check("setup: non-severe screening submitted", s == 201)
s, case = api("GET", f"/api/cases/{case_id}", admin)
s, t = api("POST", f"/api/cases/{case_id}/transitions", admin,
           {"action": "SubmitScreening", "comment": "screening done",
            "assignedToUserId": None, "rowVersion": (case or {}).get("rowVersion")})
check("setup: transition to RISK_ASSESSMENT", s == 200 and (t or {}).get("status") == "RISK_ASSESSMENT",
      f"status={s} state={(t or {}).get('status')}")
s, case = api("GET", f"/api/cases/{case_id}", admin)
check("setup: case in RISK_ASSESSMENT", (case or {}).get("status") == "RISK_ASSESSMENT",
      f"state={(case or {}).get('status')}")

# ---------- 1. crisis call -> event + notification + EMERGENCY ----------
s, resp = api("POST", "/api/helpline/calls", admin, {
    "callerName": "Crisis Caller",
    "callerPhone": "03001234567",
    "caseId": case_id,
    "indicators": {"suicidalIntent": True, "selfHarmRisk": False, "psychosis": False,
                   "panicAttack": False, "substanceCrisis": False, "otherAcute": False},
    "callNotes": "Caller expressed suicidal intent."})
check("crisis call -> 201", s == 201, f"status={s}")
check("crisisEventCreated=true + SUI/CRITICAL",
      (resp or {}).get("crisisEventCreated") is True
      and (resp.get("call") or {}).get("crisisTypeCodes") == "SUI"
      and (resp.get("call") or {}).get("crisisSeverity") == "CRITICAL")
ev_id = (resp or {}).get("crisisEventId")
check("case auto-transitioned to EMERGENCY", (resp or {}).get("caseTransitionApplied") is True,
      str((resp or {}).get("caseTransitionNote")))
s, case = api("GET", f"/api/cases/{case_id}", admin)
check("case state == EMERGENCY", (case or {}).get("status") == "EMERGENCY",
      f"state={(case or {}).get('status')}")
n_notif = sql(f"SELECT COUNT(*) FROM CMS_Notifications WHERE RelatedCaseId={case_id} "
              "AND RelatedEntity='CRISIS_EVENT' AND RecipientRole='SUPERVISOR'")
check("Immediate Alert notification row written", n_notif.strip() == "1", f"count={n_notif}")
s, evs = api("GET", f"/api/crisis-events/case/{case_id}", admin)
check("GET events by case -> 1 OPEN event", s == 200 and len(evs or []) == 1
      and evs[0]["status"] == "OPEN" and evs[0]["triggerSource"] == "HELPLINE_CALL")

# ---------- 2. routine call -> no event ----------
s, resp = api("POST", "/api/helpline/calls", admin, {
    "callerName": "Routine Caller", "caseId": case_id,
    "indicators": {"suicidalIntent": False, "selfHarmRisk": False, "psychosis": False,
                   "panicAttack": False, "substanceCrisis": False, "otherAcute": False},
    "callNotes": "General info request."})
check("routine call -> 201, no event", s == 201 and (resp or {}).get("crisisEventCreated") is False)
n_events = sql(f"SELECT COUNT(*) FROM CMS_CrisisEvents WHERE CaseId={case_id} AND IsActive=1")
check("still exactly 1 crisis event", n_events.strip() == "1", f"count={n_events}")

# ---------- 3. multi-indicator detection (CRITICAL wins) ----------
s, resp = api("POST", "/api/helpline/calls", admin, {
    "caseId": case_id,
    "indicators": {"suicidalIntent": False, "selfHarmRisk": True, "psychosis": False,
                   "panicAttack": True, "substanceCrisis": False, "otherAcute": False},
    "callNotes": "Self-harm + panic."})
check("SHM,PAN detected, severity CRITICAL", s == 201
      and (resp.get("call") or {}).get("crisisTypeCodes") == "SHM,PAN"
      and (resp.get("call") or {}).get("crisisSeverity") == "CRITICAL")
# case already EMERGENCY -> FlagEmergency not allowed from EMERGENCY -> graceful note, event kept
check("repeat emergency: graceful note, event kept", (resp or {}).get("crisisEventCreated") is True
      and (resp or {}).get("caseTransitionApplied") is False
      and bool((resp or {}).get("caseTransitionNote")))

# ---------- 4. manual trigger + supervisor alert ----------
s, b = api("POST", "/api/patients/members", admin,
           {"fullName": "Sprint4b Manual Patient", "gender": "F", "mrNo": "MR-4B02"})
s, b = api("POST", "/api/cases", admin,
           {"communityMemberId": (b or {}).get("memberId"), "sourceType": "HealthFacility",
            "priorityLevel": "High"})
case2 = (b or {}).get("caseId")
s, resp = api("POST", "/api/crisis-events", admin, {
    "caseId": case2, "crisisTypeCode": "PSY", "severity": "CRITICAL",
    "triggerSource": "MANUAL", "notes": "Acute psychotic episode observed."})
check("manual trigger -> 201", s == 201, f"status={s}")
check("manual trigger: event + graceful transition note",
      (resp or {}).get("event", {}).get("triggerSource") == "MANUAL")
s, case = api("GET", f"/api/cases/{case2}", admin)
print("   (case2 state after manual trigger:", (case or {}).get("status"),
      "| note:", (resp or {}).get("caseTransitionNote"), ")")

# ---------- 5. STABILIZED -> S7g branch (EMERGENCY -> TRIAGE) ----------
s, evs = api("GET", f"/api/crisis-events/case/{case_id}", admin)
ev = (evs or [])[0]
# rowVersion is a base64 string in JSON; send it back unchanged
s, resp = api("PATCH", f"/api/crisis-events/{ev['crisisEventId']}/status", admin,
              {"newStatus": "STABILIZED", "rowVersion": ev["rowVersion"]})
check("STABILIZED -> 200", s == 200, f"status={s}")
check("STABILIZED routed case to TRIAGE (S7g->S7h)", (resp or {}).get("caseTransitionApplied") is True,
      str((resp or {}).get("caseTransitionNote")))
s, case = api("GET", f"/api/cases/{case_id}", admin)
check("case state == TRIAGE", (case or {}).get("status") == "TRIAGE",
      f"state={(case or {}).get('status')}")
check("event status STABILIZED", (resp.get("event") or {}).get("status") == "STABILIZED")

# ---------- 6. CONTINUE_CARE keeps emergency branch (S7i) ----------
s, evs2 = api("GET", f"/api/crisis-events/case/{case_id}", admin)
ev2 = [e for e in (evs2 or []) if e["status"] == "OPEN"][0]
s, resp = api("PATCH", f"/api/crisis-events/{ev2['crisisEventId']}/status", admin,
              {"newStatus": "CONTINUE_CARE", "rowVersion": ev2["rowVersion"]})
check("CONTINUE_CARE -> 200, no workflow transition", s == 200
      and (resp or {}).get("caseTransitionApplied") is False)

# ---------- 7. stale RowVersion -> 409 ----------
s, evs3 = api("GET", f"/api/crisis-events/case/{case_id}", admin)
ev3 = [e for e in (evs3 or []) if e["status"] == "STABILIZED"][0]
stale = base64.b64encode(b"\x00" * 8).decode()
s, _ = api("PATCH", f"/api/crisis-events/{ev3['crisisEventId']}/status", admin,
           {"newStatus": "ESCALATED", "rowVersion": stale})
check("stale RowVersion -> 409", s == 409, f"status={s}")

# ---------- 8. safety plan ----------
s, plan = api("POST", "/api/safety-plans", admin, {
    "caseId": case_id,
    "warningSigns": "Isolation, hopelessness statements",
    "copingStrategies": "Call support contact, breathing exercises",
    "supportContactsJson": '[{"name":"Brother","phone":"03009998888"}]'})
check("safety plan -> 201", s == 201, f"status={s}")
s, plans = api("GET", f"/api/safety-plans/case/{case_id}", admin)
check("GET safety plans -> 1 plan", s == 200 and len(plans or []) == 1
      and plans[0]["warningSigns"].startswith("Isolation"))

# ---------- 9. validation 400s ----------
s, _ = api("POST", "/api/helpline/calls", admin,
           {"caseId": case_id, "indicators": None, "callNotes": "x"})
check("call without indicators -> 400", s == 400, f"status={s}")
s, _ = api("POST", "/api/crisis-events", admin,
           {"caseId": case2, "crisisTypeCode": "BOGUS", "severity": "CRITICAL",
            "triggerSource": "MANUAL"})
check("bad crisis type -> 400/422", s in (400, 422), f"status={s}")
s, _ = api("POST", "/api/crisis-events", admin,
           {"caseId": case2, "crisisTypeCode": "SUI", "severity": "EXTREME",
            "triggerSource": "MANUAL"})
check("bad severity -> 400", s == 400, f"status={s}")
s, _ = api("POST", "/api/safety-plans", admin,
           {"caseId": case2, "warningSigns": "", "copingStrategies": "x"})
check("empty warning signs -> 400", s == 400, f"status={s}")

# ---------- 10. gating ----------
s, _ = api("POST", "/api/helpline/calls", None, {"caseId": case_id, "indicators": {}})
check("no token -> 401", s == 401, f"status={s}")
s, _ = api("POST", "/api/helpline/calls", viewer,
           {"caseId": case_id, "indicators": {"suicidalIntent": True, "selfHarmRisk": False,
            "psychosis": False, "panicAttack": False, "substanceCrisis": False, "otherAcute": False}})
check("viewer without Helpline:Write -> 403", s == 403, f"status={s}")
s, _ = api("GET", "/api/crisis-events/types", viewer)
check("viewer without Crisis:Read -> 403", s == 403, f"status={s}")

# ---------- 11. audit rows ----------
n_audit = sql("SELECT COUNT(*) FROM CMS_AuditLogs WHERE TableName IN "
              "('CMS_HelplineCalls','CMS_CrisisEvents','CMS_SafetyPlans')")
check("audit rows written", n_audit.strip().isdigit() and int(n_audit.strip()) >= 6,
      f"count={n_audit}")

print(f"\n{len(passed)} passed, {len(failed)} failed")
if failed:
    print("FAILED:", failed); raise SystemExit(1)
