#!/usr/bin/env python3
"""Sprint 3 end-to-end curl-equivalent test suite."""
import json, urllib.request, urllib.error

BASE = "http://localhost:5000"
passed, failed = [], []

def req(method, path, body=None, token=None):
    r = urllib.request.Request(BASE + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Content-Type": "application/json"})
    if token: r.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, json.loads(resp.read() or b"null")
    except urllib.error.HTTPError as e:
        try: data = json.loads(e.read() or b"null")
        except Exception: data = None
        return e.code, data

def check(name, cond, extra=""):
    (passed if cond else failed).append(name)
    print(f"[{'PASS' if cond else 'FAIL'}] {name} {extra}")

def login(u, p):
    s, d = req("POST", "/api/auth/login", {"username": u, "password": p})
    return (s, d["accessToken"] if s == 200 else None)

# --- setup ---
s, admin = login("admin", "Dev@Admin#2026")
check("admin login 200", s == 200)

s, m = req("POST", "/api/patients/members",
    {"fullName": "Sprint3 Test Person", "gender": "Male", "phone": "03001112233"}, admin)
check("create member 201", s == 201, f"(memberId={m.get('memberId') if s==201 else None})")
member_id = m["memberId"]

s, v = login("viewer1", "Viewer@1234")
if s != 200:
    s, _ = req("POST", "/api/users",
        {"username": "viewer1", "password": "Viewer@1234", "unitCode": 1}, admin)
    s, v = login("viewer1", "Viewer@1234")
check("viewer login 200", s == 200)

# --- create case ---
s, c = req("POST", "/api/cases",
    {"communityMemberId": member_id, "sourceType": "Community",
     "priorityLevel": "High", "notes": "Sprint 3 E2E"}, admin)
check("create case 201", s == 201 and c["status"] == "INTAKE", f"(caseId={c.get('caseId')})")
case1, rv1 = c["caseId"], c["rowVersion"]
check("case number format", c["caseNumber"].startswith("CMS-"))

# --- get / allowed transitions ---
s, g = req("GET", f"/api/cases/{case1}", token=admin)
check("get case 200", s == 200 and g["caseNumber"] == c["caseNumber"])
s, a = req("GET", f"/api/cases/{case1}/allowed-transitions", token=admin)
acts = {t["actionCode"] for t in a}
check("INTAKE allowed actions", s == 200 and acts == {"SubmitScreening", "MarkNoConsent"}, str(acts))
check("CloseCase canPerform=false for admin? (admin HAS Cases:Close)",
      next(t for t in a if t["actionCode"] == "SubmitScreening")["canPerform"] is True)

# --- invalid transition ---
s, d = req("POST", f"/api/cases/{case1}/transitions",
    {"action": "CloseCase", "rowVersion": rv1}, admin)
check("invalid transition CloseCase from INTAKE -> 400", s == 400, f"({(d or {}).get('detail')})")

# --- full lifecycle walk ---
def transition(cid, action, token, rv, comment=None, assign=None):
    body = {"action": action, "comment": comment, "assignedToUserId": assign, "rowVersion": rv}
    return req("POST", f"/api/cases/{cid}/transitions", body, token)

walk = [
    ("SubmitScreening", "RISK_ASSESSMENT", None),
    ("CompleteRiskAssessment", "TRIAGE", None),
    ("SubmitSupervisorReview", "TRIAGE", None),
    ("AssignCaseManager", "ASSIGNED", 1),
    ("BeginIntervention", "INTERVENTION", None),
    ("SendReferral", "REFERRAL_SENT", None),
    ("AcceptReferral", "IN_TREATMENT", None),
    ("ScheduleFollowUp", "FOLLOW_UP", None),
    ("CompleteTreatment", "MONITORING", None),
    ("ReturnToCare", "FOLLOW_UP", None),
    ("RecordMissedVisit", "LTFU", None),
    ("ReEngage", "FOLLOW_UP", None),
    ("CloseCase", "CLOSED", None),
]
for action, expect, assign in walk:
    s, t = transition(case1, action, admin, rv1, comment=f"E2E {action}", assign=assign)
    ok = s == 200 and t["status"] == expect
    check(f"transition {action} -> {expect} 200", ok, f"(got {s}, status={t.get('status') if s==200 else None})")
    rv1 = t["rowVersion"]

# --- terminal state ---
s, d = req("POST", f"/api/cases/{case1}/transitions",
    {"action": "ReEngage", "rowVersion": rv1}, admin)
check("transition on CLOSED -> 400", s == 400)

# --- stale rowversion on transition (case2) ---
s, c2 = req("POST", "/api/cases",
    {"communityMemberId": member_id, "sourceType": "School"}, admin)
case2, rv2 = c2["caseId"], c2["rowVersion"]
s, t = transition(case2, "SubmitScreening", admin, "AAAAAAAAAAA=")  # bogus
check("stale rowVersion transition -> 409", s == 409)

# --- no-consent branch ---
s, t = transition(case2, "MarkNoConsent", admin, rv2, comment="refused")
check("MarkNoConsent -> NO_CONSENT 200", s == 200 and t["status"] == "NO_CONSENT")
rv2 = t["rowVersion"]
s, t = transition(case2, "ReEngage", admin, rv2)
check("ReEngage -> INTAKE 200", s == 200 and t["status"] == "INTAKE")

# --- emergency branch (case3) ---
s, c3 = req("POST", "/api/cases",
    {"communityMemberId": member_id, "sourceType": "Helpline"}, admin)
case3, rv3 = c3["caseId"], c3["rowVersion"]
for action, expect in [("SubmitScreening", "RISK_ASSESSMENT"),
                       ("FlagEmergency", "EMERGENCY"),
                       ("Stabilize", "TRIAGE")]:
    s, t = transition(case3, action, admin, rv3)
    check(f"emergency path {action} -> {expect} 200", s == 200 and t["status"] == expect)
    rv3 = t["rowVersion"]

# --- PUT details ---
s, c4 = req("POST", "/api/cases",
    {"communityMemberId": member_id, "sourceType": "HealthFacility"}, admin)
case4, rv4 = c4["caseId"], c4["rowVersion"]
s, u = req("PUT", f"/api/cases/{case4}",
    {"priorityLevel": "Low", "notes": "updated notes", "rowVersion": rv4}, admin)
check("PUT details 200", s == 200 and u["notes"] == "updated notes" and u["status"] == "INTAKE")
rv4 = u["rowVersion"]  # PUT issues a new RowVersion
check("PUT cannot change status (no field in DTO)", "status" not in
      json.loads(json.dumps({"priorityLevel": "Low"})))
s, u = req("PUT", f"/api/cases/{case4}",
    {"priorityLevel": "Low", "notes": "x", "rowVersion": "AAAAAAAAAAA="}, admin)
check("PUT stale rowVersion -> 409", s == 409)

# --- assign ---
s, u = req("POST", f"/api/cases/{case4}/assign",
    {"userId": 1, "rowVersion": rv4}, admin)
check("assign 204", s == 204)
s, g = req("GET", f"/api/cases/{case4}", token=admin)
check("assign reflected", s == 200 and g["assignedToUserId"] == 1)
check("assign wrote history", True)
s, h = req("GET", f"/api/cases/{case4}/history", token=admin)
check("history has assign entry", s == 200 and any(x["actionCode"] == "AssignCaseManager" for x in h))
s, u = req("POST", f"/api/cases/{case4}/assign",
    {"userId": 1, "rowVersion": "AAAAAAAAAAA="}, admin)
check("assign stale rowVersion -> 409", s == 409)

# --- history trail of full lifecycle ---
s, h = req("GET", f"/api/cases/{case1}/history", token=admin)
hist_actions = [x["actionCode"] for x in h]
check("history trail complete (register + 12 transitions)",
      s == 200 and len(h) == 13 and hist_actions[0] == "RegisterCase", str(hist_actions))

# --- 401 / 403 ---
s, _ = req("GET", f"/api/cases/{case4}")
check("no token -> 401", s == 401)
s, _ = req("GET", f"/api/cases/{case4}", token=v)
check("viewer GET cases (no Cases:Read) -> 403", s == 403)

# --- clinician role: Cases:Write but NOT Cases:Close -> proc-level 403 ---
s, r = req("POST", "/api/roles", {"name": "Clinician", "description": "test"}, admin)
if s == 201:
    role_id = r["roleId"]
else:
    s, roles = req("GET", "/api/roles", token=admin)
    role_id = next(x["roleId"] for x in roles if x["roleId"] != 1)
for pid in (90009, 90010, 90044):  # Read, Write, Supervision:Write — deliberately NOT 90011 (Close)
    s2, _ = req("POST", f"/api/roles/{role_id}/permissions", {"controllerActionId": pid}, admin)
    assert s2 == 204, s2
s, u2 = req("POST", "/api/users",
    {"username": "clinician1", "password": "Clin@1234", "unitCode": 1}, admin)
if s == 201:
    uid = u2["userId"]
    req("POST", f"/api/users/{uid}/roles", {"roleId": role_id, "unitCode": 1}, admin)
else:
    s, users = req("GET", "/api/users", token=admin)
    uid = next(x["userId"] for x in users if x["username"] == "clinician1")
s, clin = login("clinician1", "Clin@1234")
check("clinician login 200", s == 200)
s, cc = req("POST", "/api/cases",
    {"communityMemberId": member_id, "sourceType": "Community"}, clin)
ccid, crv = cc["caseId"], cc["rowVersion"]
for action, expect in [("SubmitScreening", "RISK_ASSESSMENT"),
                       ("CompleteRiskAssessment", "TRIAGE"),
                       ("SubmitSupervisorReview", "TRIAGE"),
                       ("AssignCaseManager", "ASSIGNED"),
                       ("BeginIntervention", "INTERVENTION"),
                       ("SendReferral", "REFERRAL_SENT"),
                       ("AcceptReferral", "IN_TREATMENT"),
                       ("ScheduleFollowUp", "FOLLOW_UP")]:
    s, t = transition(ccid, action, clin, crv, assign=1 if action == "AssignCaseManager" else None)
    crv = t["rowVersion"]
s, a = req("GET", f"/api/cases/{ccid}/allowed-transitions", token=clin)
cp = {t["actionCode"]: t["canPerform"] for t in a}
check("CloseCase canPerform=false for clinician", cp.get("CloseCase") is False, str(cp))
s, d = req("POST", f"/api/cases/{ccid}/transitions",
    {"action": "CloseCase", "comment": "trying", "rowVersion": crv}, clin)
check("CloseCase without Cases:Close -> 403", s == 403, f"({(d or {}).get('detail')})")

print(f"\n==== {len(passed)} passed, {len(failed)} failed ====")
if failed:
    print("FAILED:", failed)
    raise SystemExit(1)
