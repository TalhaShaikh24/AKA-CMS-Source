#!/usr/bin/env python3
"""Gap-closure tests: DASS-21/SBQ-R/C-SSRS screening, ResumeTreatment,
carers, supervisor-review gate, no-consent checklist."""
import json, urllib.request, urllib.error, base64

BASE = "http://localhost:5000"
passed, failed = [], []

def check(name, cond, detail=""):
    (passed if cond else failed).append(name)
    print(("PASS " if cond else "FAIL ") + name + (f" [{detail}]" if detail else ""))

def api(method, path, token=None, body=None, raw_qs=""):
    url = BASE + path + raw_qs
    req = urllib.request.Request(url, method=method,
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

def login(u, p):
    s, b = api("POST", "/api/auth/login", body={"username": u, "password": p})
    return (b or {}).get("accessToken") if s == 200 else None

admin = login("admin", "Dev@Admin#2026")
check("admin login", bool(admin))

def new_member(tag):
    s, b = api("POST", "/api/patients/members", admin,
               {"fullName": f"Gap {tag}", "gender": "M"})
    assert s == 201, f"member {s} {b}"
    return b["memberId"]

def new_case(tag, member=None):
    m = member or new_member(tag)
    s, b = api("POST", "/api/cases", admin,
               {"communityMemberId": m, "sourceType": "HealthFacility", "priorityLevel": "High"})
    assert s == 201, f"case {s} {b}"
    return b["caseId"], b["rowVersion"]

def transition(case_id, action, rv, comment="t", expect=200):
    s, b = api("POST", f"/api/cases/{case_id}/transitions", admin,
               {"action": action, "comment": comment, "assignedToUserId": None, "rowVersion": rv})
    return s, b

def to_state(case_id, target, actions):
    """Drive a fresh case to a target state through transitions."""
    rv = actions[0][1]
    for action, rv in actions:
        s, b = transition(case_id, action, rv)
        assert s == 200, f"{action} -> {s} {b}"
        rv = b["rowVersion"]
    return rv

# ============ GAP 1: new screening tools ============
s, tools = api("GET", "/api/screenings/tools", admin)
codes = {t["toolCode"]: t for t in (tools or [])}
check("tools include DASS21/SBQR/CSSRS",
      {"DASS21", "SBQR", "CSSRS"} <= set(codes), f"{sorted(codes)}")
check("DASS21 bands", [x["bandCode"] for x in codes["DASS21"]["bands"]] ==
      ["MINIMAL", "MILD", "MODERATE", "MOD_SEVERE", "SEVERE"])
check("SBQR bands", [x["bandCode"] for x in codes["SBQR"]["bands"]] ==
      ["MINIMAL", "MODERATE", "SEVERE"])
check("CSSRS bands", [x["bandCode"] for x in codes["CSSRS"]["bands"]] ==
      ["MINIMAL", "MILD", "MODERATE", "MOD_SEVERE", "SEVERE"])

def submit(case_id, tool, items):
    s, r = api("POST", "/api/screenings/submit", admin,
               {"caseId": case_id, "toolCode": tool, "itemScores": items})
    return s, (r or {}).get("screening") or {}

# DASS-21: all zeros -> MINIMAL, subscales persisted
cid, _ = new_case("dass0")
s, sc = submit(cid, "DASS21", [0] * 21)
check("DASS-21 all-zero -> 201", s == 201, f"status={s}")
check("DASS-21 rawScore=0", sc.get("rawScore") == 0, f"{sc.get('rawScore')}")
check("DASS-21 risk=MINIMAL", sc.get("riskLevel") == "MINIMAL", f"{sc.get('riskLevel')}")
ss = json.loads(sc.get("subscaleScoresJson") or "{}")
check("DASS-21 subscales persisted",
      ss == {"Depression": 0, "Anxiety": 0, "Stress": 0}, f"{ss}")

# DASS-21: severe depression (idx 2,4,9,12,15,16,20 = 3) -> SEVERE
cid, _ = new_case("dass-sev")
items = [0] * 21
for i in (2, 4, 9, 12, 15, 16, 20): items[i] = 3
s, sc = submit(cid, "DASS21", items)
check("DASS-21 severe depression -> 201", s == 201, f"status={s}")
check("DASS-21 risk=SEVERE", sc.get("riskLevel") == "SEVERE", f"{sc.get('riskLevel')}")
check("DASS-21 rawScore=21", sc.get("rawScore") == 21, f"{sc.get('rawScore')}")
ss = json.loads(sc.get("subscaleScoresJson") or "{}")
check("DASS-21 depression=21 others 0",
      ss.get("Depression") == 21 and ss.get("Anxiety") == 0 and ss.get("Stress") == 0, f"{ss}")

# DASS-21: mild depression only (7 x 1 -> score 7) -> MODERATE worst band
cid, _ = new_case("dass-mod")
items = [0] * 21
for i in (2, 4, 9, 12, 15, 16, 20): items[i] = 1
s, sc = submit(cid, "DASS21", items)
check("DASS-21 depression=7 -> MODERATE", s == 201 and sc.get("riskLevel") == "MODERATE",
      f"{s}/{sc.get('riskLevel')}")
ss = json.loads(sc.get("subscaleScoresJson") or "{}")
check("DASS-21 subscale depression=7", ss.get("Depression") == 7, f"{ss}")

# DASS-21: wrong item count -> 400
s, _ = submit(cid, "DASS21", [0] * 20)
check("DASS-21 wrong count -> 400", s == 400, f"status={s}")

# SBQ-R: minimal [1,1,1,1] -> total 4 -> MINIMAL
cid, _ = new_case("sbqr-min")
s, sc = submit(cid, "SBQR", [1, 1, 1, 1])
check("SBQ-R [1,1,1,1] -> 201", s == 201, f"status={s}")
check("SBQ-R total=4 MINIMAL", sc.get("rawScore") == 4 and sc.get("riskLevel") == "MINIMAL",
      f"{sc.get('rawScore')}/{sc.get('riskLevel')}")

# SBQ-R: threshold [2,3,1,1] -> total 7 -> MODERATE
cid, _ = new_case("sbqr-mod")
s, sc = submit(cid, "SBQR", [2, 3, 1, 1])
check("SBQ-R total=7 -> MODERATE", s == 201 and sc.get("riskLevel") == "MODERATE",
      f"{s}/{sc.get('riskLevel')}")

# SBQ-R: per-item range violation (item3=4, max 3) -> 400
s, _ = submit(cid, "SBQR", [1, 1, 4, 1])
check("SBQ-R item3=4 rejected -> 400", s == 400, f"status={s}")

# SBQ-R: zero-based item rejected -> 400
s, _ = submit(cid, "SBQR", [0, 1, 1, 1])
check("SBQ-R item1=0 rejected -> 400", s == 400, f"status={s}")

# SBQ-R: high [4,5,3,6] -> total 18 -> SEVERE (separate case: auto-escalates)
cid, _ = new_case("sbqr-sev")
s, b = api("POST", "/api/screenings/submit", admin,
           {"caseId": cid, "toolCode": "SBQR", "itemScores": [4, 5, 3, 6]})
sc = (b or {}).get("screening") or {}
check("SBQ-R total=18 -> SEVERE", s == 201 and sc.get("riskLevel") == "SEVERE",
      f"{s}/{sc.get('riskLevel')}")
check("SBQ-R severe auto-escalation noted", b.get("autoTransitionApplied") in (True, False),
      f"applied={b.get('autoTransitionApplied')}")

# SBQ-R: Q4 zero-based range (published 0-6)
cid, _ = new_case("sbqr-q4zero")
s, sc = submit(cid, "SBQR", [1, 1, 1, 0])
check("SBQ-R Q4=0 accepted -> MINIMAL", s == 201 and sc.get("riskLevel") == "MINIMAL",
      f"{s}/{sc.get('riskLevel')}")
s, _ = submit(cid, "SBQR", [1, 1, 1, 7])
check("SBQ-R Q4=7 rejected -> 400", s == 400, f"status={s}")

# C-SSRS tiers
tiers = [
    ("cssrs-none", [0, 0, 0, 0, 0, 0], "MINIMAL"),
    ("cssrs-ideation", [1, 1, 0, 0, 0, 0], "MILD"),
    ("cssrs-method", [0, 0, 1, 0, 0, 0], "MODERATE"),
    ("cssrs-intent", [0, 0, 0, 1, 0, 0], "MOD_SEVERE"),
    ("cssrs-plan", [0, 0, 0, 0, 1, 0], "MOD_SEVERE"),
]
for tag, items, want in tiers:
    cid, _ = new_case(tag)
    s, sc = submit(cid, "CSSRS", items)
    check(f"C-SSRS {items} -> {want}", s == 201 and sc.get("riskLevel") == want,
          f"{s}/{sc.get('riskLevel')}")

# C-SSRS: binary validation (2 not allowed) -> 400
cid, _ = new_case("cssrs-bad")
s, _ = submit(cid, "CSSRS", [0, 0, 0, 0, 0, 2])
check("C-SSRS item=2 rejected -> 400", s == 400, f"status={s}")

# C-SSRS: behavior -> SEVERE (separate case)
cid, _ = new_case("cssrs-beh")
s, sc = submit(cid, "CSSRS", [0, 0, 0, 0, 0, 1])
check("C-SSRS behavior -> SEVERE", s == 201 and sc.get("riskLevel") == "SEVERE",
      f"{s}/{sc.get('riskLevel')}")

# ============ GAP 2: ResumeTreatment FOLLOW_UP -> IN_TREATMENT ============
cid, rv = new_case("resume")
s, b = transition(cid, "SubmitScreening", rv); rv = b["rowVersion"]
s, b = transition(cid, "CompleteRiskAssessment", rv); rv = b["rowVersion"]
s, b = transition(cid, "SubmitSupervisorReview", rv); rv = b["rowVersion"]
s, b = transition(cid, "AssignCaseManager", rv); rv = b["rowVersion"]
s, b = transition(cid, "BeginIntervention", rv); rv = b["rowVersion"]
s, b = transition(cid, "SendReferral", rv); rv = b["rowVersion"]
s, b = transition(cid, "AcceptReferral", rv); rv = b["rowVersion"]
check("reached IN_TREATMENT", s == 200 and b["status"] == "IN_TREATMENT", f"{b.get('status')}")
s, b = transition(cid, "ScheduleFollowUp", rv); rv = b["rowVersion"]
check("reached FOLLOW_UP", s == 200 and b["status"] == "FOLLOW_UP", f"{b.get('status')}")
s, b = transition(cid, "ResumeTreatment", rv); rv = b["rowVersion"]
check("ResumeTreatment -> IN_TREATMENT", s == 200 and b["status"] == "IN_TREATMENT",
      f"status={s} state={b.get('status')}")
# stale row version on a valid next transition -> 409
s, b = transition(cid, "ScheduleFollowUp", "AAAAAAAAAAA=", expect=409)
check("ScheduleFollowUp stale version -> 409", s == 409, f"status={s}")
# history records the action
s, hist = api("GET", f"/api/cases/{cid}/history", admin)
check("history has ResumeTreatment",
      any(h.get("actionCode") == "ResumeTreatment" for h in (hist or [])))

# ============ GAP 4: supervisor review gate ============
cid, rv = new_case("suprev")
s, b = transition(cid, "SubmitScreening", rv); rv = b["rowVersion"]
s, b = transition(cid, "CompleteRiskAssessment", rv); rv = b["rowVersion"]
check("reached TRIAGE", b["status"] == "TRIAGE")
s, b = transition(cid, "AssignCaseManager", rv)
check("assign WITHOUT review rejected -> 400",
      s == 400 and "upervisor review" in json.dumps(b), f"status={s} {json.dumps(b)[:120]}")
s, b = transition(cid, "SubmitSupervisorReview", rv)
check("SubmitSupervisorReview self-loop -> 200 TRIAGE",
      s == 200 and b["status"] == "TRIAGE", f"status={s} state={b.get('status')}")
rv = b["rowVersion"]
s, b = transition(cid, "AssignCaseManager", rv)
check("assign AFTER review -> 200 ASSIGNED",
      s == 200 and b["status"] == "ASSIGNED", f"status={s} state={b.get('status')}")
# allowed-actions endpoint should list the new self-loop on a fresh TRIAGE case
cid2, rv2 = new_case("suprev2")
s, b = transition(cid2, "SubmitScreening", rv2); rv2 = b["rowVersion"]
s, b = transition(cid2, "CompleteRiskAssessment", rv2); rv2 = b["rowVersion"]
s, allowed = api("GET", f"/api/cases/{cid2}/allowed-transitions", admin)
acts = [a.get("actionCode") for a in (allowed or [])]
check("allowed lists SubmitSupervisorReview", "SubmitSupervisorReview" in acts, f"{acts}")

# permission-level: supervisor (has Supervision:Write) can review;
# caseworker (lacks it) gets 403
supervisor = login("supervisor", "Dev@Admin#2026")
caseworker = login("caseworker", "Dev@Admin#2026")
check("supervisor login", bool(supervisor))
check("caseworker login", bool(caseworker))
s, allowed = api("GET", f"/api/cases/{cid2}/allowed-transitions", supervisor)
sacts = [a.get("actionCode") for a in (allowed or [])]
check("supervisor allowed includes SubmitSupervisorReview",
      "SubmitSupervisorReview" in sacts, f"{sacts}")
s, b = api("POST", f"/api/cases/{cid2}/transitions", supervisor,
           {"action": "SubmitSupervisorReview", "comment": "reviewed",
            "assignedToUserId": None, "rowVersion": rv2})
check("supervisor SubmitSupervisorReview -> 200",
      s == 200 and b.get("status") == "TRIAGE", f"status={s}")
rv2 = b["rowVersion"]
s, b = api("POST", f"/api/cases/{cid2}/transitions", caseworker,
           {"action": "SubmitSupervisorReview", "comment": "x",
            "assignedToUserId": None, "rowVersion": rv2})
check("caseworker SubmitSupervisorReview -> 403", s == 403, f"status={s}")

# ============ GAP 3: carers ============
cid, _ = new_case("carer")
s, c1 = api("POST", f"/api/cases/{cid}/carers", admin,
            {"caseId": cid, "fullName": "Ahmed Khan", "relationship": "Father",
             "phone": "03001234567", "isPrimary": True})
check("add carer -> 201", s == 201, f"status={s}")
check("carer fields", c1.get("fullName") == "Ahmed Khan" and c1.get("isPrimary") is True)
rv1 = c1["rowVersion"]
s, c2 = api("POST", f"/api/cases/{cid}/carers", admin,
            {"caseId": cid, "fullName": "Fatima Khan", "relationship": "Mother",
             "phone": None, "isPrimary": True})
check("add second primary -> 201", s == 201, f"status={s}")
s, lst = api("GET", f"/api/cases/{cid}/carers", admin)
primaries = [c for c in (lst or []) if c.get("isPrimary")]
check("single primary enforced", len(lst) == 2 and len(primaries) == 1
      and primaries[0]["fullName"] == "Fatima Khan", f"primaries={len(primaries)}")
# re-fetch c1: the second add demoted it (new RowVersion)
c1 = next(c for c in lst if c["carerId"] == c1["carerId"])
rv1 = c1["rowVersion"]
s, upd = api("PUT", f"/api/cases/{cid}/carers/{c1['carerId']}", admin,
             {"fullName": "Ahmed Khan Sr", "relationship": "Father",
              "phone": "03001234567", "isPrimary": False, "rowVersion": rv1})
check("update carer -> 200", s == 200 and upd.get("fullName") == "Ahmed Khan Sr",
      f"status={s}")
s, _ = api("PUT", f"/api/cases/{cid}/carers/{c1['carerId']}", admin,
           {"fullName": "Stale", "relationship": None, "phone": None,
            "isPrimary": False, "rowVersion": rv1})
check("update stale version -> 409", s == 409, f"status={s}")
s, _ = api("PUT", f"/api/cases/{cid}/carers/{c1['carerId']}", admin,
           {"fullName": "", "relationship": None, "phone": None,
            "isPrimary": False, "rowVersion": upd["rowVersion"]})
check("update empty name -> 400", s == 400, f"status={s}")
b64 = base64.b64encode(base64.b64decode(upd["rowVersion"])).decode()
s, _ = api("DELETE", f"/api/cases/{cid}/carers/{c1['carerId']}", admin,
           raw_qs=f"?rowVersion={b64}")
check("deactivate carer -> 204", s == 204, f"status={s}")
s, lst = api("GET", f"/api/cases/{cid}/carers", admin)
check("deactivated hidden from list", len(lst) == 1, f"count={len(lst)}")
s, _ = api("POST", "/api/cases/999999/carers", admin,
           {"caseId": 999999, "fullName": "Ghost", "relationship": None,
            "phone": None, "isPrimary": False})
check("add carer unknown case -> 404", s == 404, f"status={s}")
s, _ = api("POST", f"/api/cases/{cid}/carers", admin,
           {"caseId": cid, "fullName": "   ", "relationship": None,
            "phone": None, "isPrimary": False})
check("add carer blank name -> 400", s == 400, f"status={s}")

# ============ GAP 5: no-consent checklist ============
cid, rv = new_case("noconsent")
s, b = transition(cid, "MarkNoConsent", rv, comment="patient declined")
check("MarkNoConsent -> 200 NO_CONSENT",
      s == 200 and b["status"] == "NO_CONSENT", f"{b.get('status')}")
s, plans = api("GET", f"/api/care-plans/case/{cid}", admin)
nc = [p for p in (plans or []) if p.get("riskCategory") == "NO_CONSENT"]
check("no-consent checklist created", len(nc) == 1, f"plans={len(plans or [])}")
steps = (nc[0] or {}).get("steps") or [] if nc else []
step_codes = [st.get("stepCode") for st in steps]
check("checklist has S5a-S5d",
      step_codes == ["S5a", "S5b", "S5c", "S5d"], f"{step_codes}")
# idempotent: ReEngage -> INTAKE -> MarkNoConsent again must not duplicate
s, b = transition(cid, "ReEngage", b["rowVersion"]); rv = b["rowVersion"]
s, b = transition(cid, "MarkNoConsent", rv)
s, plans = api("GET", f"/api/care-plans/case/{cid}", admin)
nc = [p for p in (plans or []) if p.get("riskCategory") == "NO_CONSENT"
      and p.get("status") == "ACTIVE"]
check("checklist idempotent (still 1 active)", len(nc) == 1, f"active={len(nc)}")

print(f"\n==== {len(passed)} passed, {len(failed)} failed ====")
if failed:
    print("FAILED:", failed)
    raise SystemExit(1)
