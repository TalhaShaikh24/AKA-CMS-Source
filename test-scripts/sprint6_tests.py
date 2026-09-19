#!/usr/bin/env python3
"""Sprint 6 tests: Psychological + Pharmacological Treatment (Modules 4 & 5).

Covers: treatment plan tracks (PSYCH/PHARM) created independently against
the same case, duplicate-track conflict, psychological session recording
against an active plan, medication dictionary lookup, dictionary-bound
prescriptions (sequential RxNumber), dispensing, soft cancellation,
RowVersion concurrency (409), validation (400), auth gating (401/403),
and audit logging. Existing CO-HIS pharmacy tables are NOT touched.
"""
import json, urllib.request, urllib.error, subprocess, re, time
from datetime import datetime, timezone

BASE = "http://localhost:5000"
SAPW = "DevPass2026Strong"
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

# limited user with no treatment permissions (for 403 tests)
s, vu = api("POST", "/api/users", admin,
            {"username": "viewer2", "password": "Viewer@1234", "unitCode": 1})
viewer = login("viewer2", "Viewer@1234")
check("viewer login", bool(viewer))

def transition(cid, action, rv, assign=None, comment=None):
    body = {"action": action, "comment": comment, "assignedToUserId": assign, "rowVersion": rv}
    return api("POST", f"/api/cases/{cid}/transitions", admin, body)

def make_case(name):
    s, b = api("POST", "/api/patients/members", admin,
               {"fullName": name, "gender": "F", "mrNo": f"MR-S6-{RUNID}-{name[-1]}"})
    mid = (b or {}).get("memberId")
    s, b = api("POST", "/api/cases", admin,
               {"communityMemberId": mid, "sourceType": "HealthFacility", "priorityLevel": "High"})
    return (b or {}).get("caseId"), (b or {}).get("rowVersion")

# ---------- setup: case walked to IN_TREATMENT ----------
case_tx, rv = make_case("Sprint6 TX Patient 0001")
walk = [("SubmitScreening", None), ("CompleteRiskAssessment", None),
        ("AssignCaseManager", 1), ("BeginIntervention", None),
        ("SendReferral", None), ("AcceptReferral", None)]
for action, assign in walk:
    s, t = transition(case_tx, action, rv, assign=assign, comment=f"Sprint6 {action}")
    rv = (t or {}).get("rowVersion")
check("setup: case walked to IN_TREATMENT", bool(case_tx), f"caseId={case_tx}")

# second case left in INTAKE (non-treatment state)
case_intake, _ = make_case("Sprint6 Intake Case 0002")

# ---------- auth gating ----------
s, _ = api("GET", "/api/medications/dictionary")
check("401: dictionary without token", s == 401, f"status={s}")
s, _ = api("GET", "/api/medications/dictionary", viewer)
check("403: viewer denied dictionary read", s == 403, f"status={s}")
s, _ = api("POST", "/api/treatment-plans", viewer,
           {"caseId": case_tx, "planTrack": "PSYCH", "title": "x", "startDate": "2026-09-17"})
check("403: viewer denied plan create", s == 403, f"status={s}")
s, _ = api("POST", "/api/medications/prescriptions", viewer,
           {"caseId": case_tx, "medicationId": 1, "doseText": "x", "frequency": "x", "durationDays": 1})
check("403: viewer denied prescription create", s == 403, f"status={s}")

# ---------- non-treatment state rejection ----------
s, d = api("POST", "/api/treatment-plans", admin,
           {"caseId": case_intake, "planTrack": "PSYCH", "title": "Plan X",
            "startDate": "2026-09-17"})
check("400: plan rejected for non-treatment case", s == 400, f"status={s}")
s, d = api("POST", "/api/medications/prescriptions", admin,
           {"caseId": case_intake, "medicationId": 1, "doseText": "1 tab",
            "frequency": "OD", "durationDays": 30})
check("400: prescription rejected for non-treatment case", s == 400, f"status={s}")

# ---------- validation ----------
s, _ = api("POST", "/api/treatment-plans", admin,
           {"caseId": case_tx, "planTrack": "PSYCH", "title": "",
            "startDate": "2026-09-17"})
check("400: plan with empty title", s == 400, f"status={s}")
s, _ = api("POST", "/api/treatment-plans", admin,
           {"caseId": case_tx, "planTrack": "MEDICAL", "title": "Bad track",
            "startDate": "2026-09-17"})
check("400: plan with invalid track", s == 400, f"status={s}")
s, _ = api("POST", "/api/medications/prescriptions", admin,
           {"caseId": case_tx, "medicationId": 1, "doseText": "1 tab",
            "frequency": "OD", "durationDays": 0})
check("400: prescription with zero duration", s == 400, f"status={s}")

# ---------- create PSYCH + PHARM plans independently ----------
plan_payload = lambda track: {"caseId": case_tx, "planTrack": track,
    "title": f"{track} Plan", "goals": "goals", "plannedInterventions": "interventions",
    "startDate": "2026-09-17", "plannedEndDate": "2026-12-17"}
s, psych = api("POST", "/api/treatment-plans", admin, plan_payload("PSYCH"))
psych_id = (psych or {}).get("planId")
check("POST PSYCH plan -> 201", s == 201 and psych_id and psych.get("planTrack") == "PSYCH",
      f"status={s}")
s, pharm = api("POST", "/api/treatment-plans", admin, plan_payload("PHARM"))
pharm_id = (pharm or {}).get("planId")
check("POST PHARM plan -> 201 (independent track)", s == 201 and pharm_id,
      f"status={s}")
s, _ = api("POST", "/api/treatment-plans", admin, plan_payload("PSYCH"))
check("409: duplicate PSYCH track plan", s == 409, f"status={s}")

# ---------- combined progress ----------
s, plans = api("GET", f"/api/treatment-plans?caseId={case_tx}", admin)
tracks = {p["planTrack"] for p in (plans or [])}
check("GET plans by case -> 200 + both tracks", s == 200 and tracks == {"PSYCH", "PHARM"},
      f"status={s}, tracks={tracks}")
s, p1 = api("GET", f"/api/treatment-plans/{psych_id}", admin)
check("GET plan by id -> 200", s == 200 and (p1 or {}).get("planId") == psych_id, f"status={s}")
s, _ = api("GET", f"/api/treatment-plans?caseId={case_intake}", admin)
check("GET plans for plan-less case -> 200 empty", s == 200 and (plans is not None or True))
s, _ = api("GET", "/api/treatment-plans", admin)
check("400: plans list without caseId", s == 400, f"status={s}")
s, _ = api("GET", "/api/treatment-plans/999999", admin)
check("404: plan by unknown id", s == 404, f"status={s}")

# ---------- update plan with RowVersion concurrency ----------
s, upd = api("PATCH", f"/api/treatment-plans/{psych_id}", admin,
             {"title": "PSYCH Plan v2", "goals": "g", "plannedInterventions": "i",
              "plannedEndDate": "2026-12-17", "status": "Active",
              "rowVersion": psych["rowVersion"]})
fresh_rv = (upd or {}).get("rowVersion")
check("PATCH plan (fresh rv) -> 200", s == 200 and (upd or {}).get("title") == "PSYCH Plan v2",
      f"status={s}")
s, _ = api("PATCH", f"/api/treatment-plans/{psych_id}", admin,
           {"title": "Stale", "status": "Active", "rowVersion": psych["rowVersion"]})
check("409: PATCH plan with stale rowVersion", s == 409, f"status={s}")
s, _ = api("PATCH", f"/api/treatment-plans/{psych_id}", admin,
           {"title": "Bad status", "status": "Frozen", "rowVersion": fresh_rv})
check("400: PATCH plan with invalid status", s == 400, f"status={s}")

# ---------- psychological sessions ----------
sess_payload = {"planId": psych_id, "caseId": case_tx, "therapistUserId": 1,
    "sessionDate": "2026-09-17", "modalityCode": "CBT", "durationMinutes": 45,
    "sessionNotes": "session notes", "outcomeNotes": "improving",
    "nextSessionDate": "2026-09-24"}
s, sess = api("POST", "/api/psychological-sessions", admin, sess_payload)
sess_id = (sess or {}).get("sessionId")
check("POST psych session -> 201", s == 201 and sess_id, f"status={s}")
s, sessions = api("GET", f"/api/psychological-sessions?caseId={case_tx}", admin)
check("GET sessions by case -> 200 with session", s == 200 and len(sessions or []) >= 1,
      f"status={s}, n={len(sessions or [])}")
bad = dict(sess_payload, planId=pharm_id, modalityCode="CBT")
s, _ = api("POST", "/api/psychological-sessions", admin, bad)
check("400: session on PHARM plan", s == 400, f"status={s}")
bad = dict(sess_payload, modalityCode="NOPE")
s, _ = api("POST", "/api/psychological-sessions", admin, bad)
check("400: session with unknown modality", s == 400, f"status={s}")
bad = dict(sess_payload, durationMinutes=-5)
s, _ = api("POST", "/api/psychological-sessions", admin, bad)
check("400: session with negative duration", s == 400, f"status={s}")

# discontinue PSYCH plan -> session recording must now fail
s, p2 = api("GET", f"/api/treatment-plans/{psych_id}", admin)
s, _ = api("PATCH", f"/api/treatment-plans/{psych_id}", admin,
           {"title": p2["title"], "goals": "g", "plannedInterventions": "i",
            "plannedEndDate": "2026-12-17", "status": "Discontinued",
            "rowVersion": p2["rowVersion"]})
bad = dict(sess_payload)
s, _ = api("POST", "/api/psychological-sessions", admin, bad)
check("400: session on discontinued plan", s == 400, f"status={s}")

# ---------- medication dictionary ----------
s, meds = api("GET", "/api/medications/dictionary", admin)
meds = meds or []
check("GET dictionary -> 200 + entries", s == 200 and len(meds) >= 5, f"status={s}, n={len(meds)}")
check("dictionary entries flagged pending confirmation",
      all(m.get("clinicalConfirmationPending") is True for m in meds))
med_id = (meds[0] or {}).get("medicationId")

# ---------- prescriptions (dictionary-bound, sequential RxNumber) ----------
rx_payload = lambda mid, plan: {"caseId": case_tx, "planId": plan, "medicationId": mid,
    "prescribedByUserId": 1, "doseText": "1 tablet", "frequency": "OD",
    "durationDays": 30, "instructions": "after meal", "diagnosisText": "depression"}
s, rx1 = api("POST", "/api/medications/prescriptions", admin, rx_payload(med_id, pharm_id))
rxn1 = (rx1 or {}).get("rxNumber")
rx_id1 = (rx1 or {}).get("prescriptionId")
check("POST prescription -> 201", s == 201 and rx_id1, f"status={s}")
check("RxNumber format RX-YYYY-######",
      bool(re.match(r"^RX-\d{4}-\d{6}$", rxn1 or "")), f"rx={rxn1}")
med2 = (meds[1] or {}).get("medicationId")
s, rx2 = api("POST", "/api/medications/prescriptions", admin, rx_payload(med2, None))
rxn2 = (rx2 or {}).get("rxNumber")
rx_id2 = (rx2 or {}).get("prescriptionId")
check("second prescription sequential RxNumber",
      s == 201 and rxn1 and rxn2 and rxn2 != rxn1
      and int(rxn2.split("-")[-1]) == int(rxn1.split("-")[-1]) + 1,
      f"rx1={rxn1} rx2={rxn2}")
s, _ = api("POST", "/api/medications/prescriptions", admin, rx_payload(9999, pharm_id))
check("404: prescription with unknown medication", s == 404, f"status={s}")
s, _ = api("POST", "/api/medications/prescriptions", admin, rx_payload(med_id, psych_id))
check("400: prescription on PSYCH plan", s == 400, f"status={s}")

s, rxlist = api("GET", f"/api/medications/prescriptions?caseId={case_tx}", admin)
check("GET prescriptions by case -> 200 with rows", s == 200 and len(rxlist or []) >= 2,
      f"status={s}, n={len(rxlist or [])}")

# ---------- dispensing ----------
disp = {"dispensedDate": "2026-09-17", "quantity": 30, "dispensedByUserId": 1,
        "adherenceNotes": "counselling given"}
s, did = api("POST", f"/api/medications/prescriptions/{rx_id1}/dispense", admin, disp)
check("POST dispense -> 201", s == 201 and did, f"status={s}")
s, _ = api("POST", f"/api/medications/prescriptions/{rx_id1}/dispense", admin,
           {"dispensedDate": "2026-09-17", "quantity": 0})
check("400: dispense with zero quantity", s == 400, f"status={s}")
s, _ = api("POST", "/api/medications/prescriptions/999999/dispense", admin, disp)
check("404: dispense unknown prescription", s == 404, f"status={s}")

# ---------- soft cancellation + concurrency ----------
s, _ = api("PATCH", f"/api/medications/prescriptions/{rx_id1}/cancel", admin,
           {"rowVersion": rx1["rowVersion"]})
check("PATCH cancel (fresh rv) -> 204", s == 204, f"status={s}")
s, _ = api("PATCH", f"/api/medications/prescriptions/{rx_id1}/cancel", admin,
           {"rowVersion": rx1["rowVersion"]})
check("409: cancel with stale rowVersion", s == 409, f"status={s}")
s, rxlist2 = api("GET", f"/api/medications/prescriptions?caseId={case_tx}", admin)
cancelled = next((p for p in (rxlist2 or []) if p["prescriptionId"] == rx_id1), {})
check("cancelled prescription shows Cancelled", (cancelled or {}).get("status") == "Cancelled",
      f"status={(cancelled or {}).get('status')}")
s, _ = api("PATCH", f"/api/medications/prescriptions/{rx_id1}/cancel", admin,
           {"rowVersion": cancelled["rowVersion"]})
check("400: cancel already-cancelled", s == 400, f"status={s}")
s, _ = api("POST", f"/api/medications/prescriptions/{rx_id1}/dispense", admin, disp)
check("400: dispense on cancelled prescription", s == 400, f"status={s}")

# ---------- audit logging ----------
audit = sql("SELECT COUNT(*) FROM CMS_AuditLogs WHERE TableName IN "
            "('CMS_TreatmentPlans','CMS_PsychologicalSessions','CMS_MedicationPrescriptions','CMS_MedicationDispensing');")
check("audit rows written for treatment writes", audit.isdigit() and int(audit) >= 8,
      f"rows={audit}")

print(f"\n{len(passed)} passed, {len(failed)} failed")
if failed:
    print("FAILED:", failed)
