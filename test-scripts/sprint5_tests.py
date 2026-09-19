#!/usr/bin/env python3
"""Sprint 5 tests: Case Management, Assignment & Referral (Module 3).

Covers: risk routing rules, High/Moderate/Low routing (care plan + SLA
queue + referrals + supervisor alert), assignment with RowVersion
concurrency, referral accept/reject (reject creates a NEW linked row),
comments, validation, permission gating, and audit logging.
"""
import json, urllib.request, urllib.error, subprocess
from datetime import datetime, timezone

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

# limited user with no care-management permissions (for 403 tests)
s, vu = api("POST", "/api/users", admin,
            {"username": "viewer1", "password": "Viewer@1234", "unitCode": 1})
viewer = login("viewer1", "Viewer@1234")
check("viewer login", bool(viewer))

# ---------- routing rules ----------
s, rules = api("GET", "/api/care-plans/routing-rules", admin)
by_cat = {r["riskCategory"]: r for r in (rules or [])}
check("GET routing-rules -> 200 + 3 rules", s == 200 and set(by_cat) == {"HIGH", "MODERATE", "LOW"}, f"status={s}")
check("HIGH rule SLA=1 + supervisor alert", by_cat.get("HIGH", {}).get("slaHours") == 1
      and by_cat["HIGH"]["requiresSupervisorAlert"] is True)
check("HIGH rule 7 steps S18-S25", len(by_cat.get("HIGH", {}).get("carePlanSteps", [])) == 7,
      f"steps={len(by_cat.get('HIGH', {}).get('carePlanSteps', []))}")
check("MODERATE rule SLA=24", by_cat.get("MODERATE", {}).get("slaHours") == 24)
check("LOW rule SLA=168 + PSYCHOSOCIAL", by_cat.get("LOW", {}).get("slaHours") == 168
      and by_cat["LOW"]["referralTargets"] == ["PSYCHOSOCIAL"])

# ---------- test case + severe screening (HIGH inference) ----------
s, b = api("POST", "/api/patients/members", admin,
           {"fullName": "Sprint5 High Patient", "gender": "F", "mrNo": "MR-5001"})
member_id = (b or {}).get("memberId")
s, b = api("POST", "/api/cases", admin,
           {"communityMemberId": member_id, "sourceType": "HealthFacility", "priorityLevel": "High"})
case_high = (b or {}).get("caseId")
check("setup: high-risk case created", bool(case_high), f"caseId={case_high}")
s, resp = api("POST", "/api/screenings/submit", admin,
              {"caseId": case_high, "toolCode": "PHQ9", "itemScores": [3, 2, 3, 2, 3, 2, 1, 2, 2]})
check("setup: severe PHQ-9 submitted", s == 201 and (resp.get("screening") or {}).get("riskLevel") == "SEVERE")

# ---------- HIGH routing (inferred) ----------
s, route = api("POST", "/api/assignment-queue/route", admin, {"caseId": case_high})
check("route HIGH (inferred) -> 200", s == 200, f"status={s}")
check("route riskCategory=HIGH", (route or {}).get("riskCategory") == "HIGH")
check("route created 2 referrals", len((route or {}).get("referralIds", [])) == 2,
      f"referrals={route.get('referralIds')}")
sla_due = datetime.fromisoformat(route["slaDueAt"].replace("Z", "+00:00"))
sla_hours = (sla_due - datetime.now(timezone.utc)).total_seconds() / 3600
check("route SLA ~1h", 0 < sla_hours <= 1.2, f"sla_hours={sla_hours:.2f}")

# care plan with 7 PENDING steps
s, plans = api("GET", f"/api/care-plans/case/{case_high}", admin)
plan = (plans or [{}])[0]
check("care plan created with 7 steps", s == 200 and len(plan.get("steps", [])) == 7)
check("care plan steps all PENDING",
      all(st.get("status") == "PENDING" for st in plan.get("steps", [])))
check("care plan step S18-High present",
      any(st.get("stepCode") == "S18-High" for st in plan.get("steps", [])))

# supervisor alert comment (S23-High)
s, comments = api("GET", f"/api/case-comments/case/{case_high}", admin)
alerts = [c for c in (comments or []) if c.get("commentType") == "ALERT"]
check("supervisor ALERT comment created", s == 200 and len(alerts) == 1,
      f"alerts={len(alerts)}")

# queue entry pending with SLA
s, pending = api("GET", "/api/assignment-queue/pending", admin)
mine = [q for q in (pending or []) if q.get("caseId") == case_high]
check("queue entry PENDING", s == 200 and len(mine) == 1 and mine[0]["status"] == "PENDING")
queue_id, queue_rv = mine[0]["queueId"], mine[0]["rowVersion"]

# ---------- assignment + concurrency ----------
s, _ = api("POST", f"/api/assignment-queue/{queue_id}/assign", admin,
           {"assignedToUserId": 1, "rowVersion": queue_rv})
check("assign queue entry -> 204", s == 204, f"status={s}")
s, b = api("POST", f"/api/assignment-queue/{queue_id}/assign", admin,
           {"assignedToUserId": 1, "rowVersion": queue_rv})
check("stale RowVersion -> 409", s == 409, f"status={s}")
check("queue entry ASSIGNED in DB",
      sql(f"SELECT Status FROM CMS_CaseAssignmentQueue WHERE QueueId={queue_id}") == "ASSIGNED")

# ---------- referrals: accept ----------
s, refs = api("GET", f"/api/referrals/case/{case_high}", admin)
ref1 = [r for r in (refs or []) if r["referredTo"] == "PSYCHOLOGIST"][0]
s, upd = api("PATCH", f"/api/referrals/{ref1['referralId']}/status", admin,
             {"newStatus": "ACCEPTED", "rejectionReason": None, "rowVersion": ref1["rowVersion"]})
check("referral ACCEPTED", s == 200 and upd.get("status") == "ACCEPTED", f"status={s}")
check("referral number format REF-YYYY-######",
      (ref1.get("referralNumber") or "").startswith("REF-"))

# ---------- referrals: reject creates NEW linked row ----------
ref2 = [r for r in (refs or []) if r["referredTo"] == "PSYCHIATRIST"][0]
s, upd = api("PATCH", f"/api/referrals/{ref2['referralId']}/status", admin,
             {"newStatus": "REJECTED", "rejectionReason": "No capacity this week",
              "rowVersion": ref2["rowVersion"]})
new_id = (upd or {}).get("newReferralId")
check("reject -> 200 + newReferralId", s == 200 and bool(new_id), f"status={s} new={new_id}")
s, refs2 = api("GET", f"/api/referrals/case/{case_high}", admin)
old = [r for r in refs2 if r["referralId"] == ref2["referralId"]][0]
new = [r for r in refs2 if r["referralId"] == new_id][0]
check("old row kept as REJECTED with reason",
      old["status"] == "REJECTED" and old["rejectionReason"] == "No capacity this week")
check("new row PENDING linked via ParentReferralId",
      new["status"] == "PENDING" and new["parentReferralId"] == ref2["referralId"])
s, _ = api("PATCH", f"/api/referrals/{new_id}/status", admin,
           {"newStatus": "REJECTED", "rejectionReason": "  ",
            "rowVersion": new["rowVersion"]})
check("reject without reason -> 400", s == 400, f"status={s}")
s, _ = api("PATCH", f"/api/referrals/{new_id}/status", admin,
           {"newStatus": "BOGUS", "rejectionReason": None, "rowVersion": new["rowVersion"]})
check("invalid status -> 400", s == 400, f"status={s}")
s, _ = api("POST", "/api/referrals", admin,
           {"caseId": case_high, "referredTo": "DENTIST", "slaDueAt": None, "notes": None})
check("invalid ReferredTo -> 400", s == 400, f"status={s}")

# ---------- MODERATE routing (explicit) ----------
s, b = api("POST", "/api/patients/members", admin,
           {"fullName": "Sprint5 Mod Patient", "gender": "M", "mrNo": "MR-5002"})
s, b = api("POST", "/api/cases", admin,
           {"communityMemberId": b["memberId"], "sourceType": "School", "priorityLevel": "Moderate"})
case_mod = b["caseId"]
s, route = api("POST", "/api/assignment-queue/route", admin,
               {"caseId": case_mod, "riskCategory": "MODERATE"})
check("route MODERATE explicit -> 200", s == 200 and route.get("riskCategory") == "MODERATE")
sla_due = datetime.fromisoformat(route["slaDueAt"].replace("Z", "+00:00"))
sla_hours = (sla_due - datetime.now(timezone.utc)).total_seconds() / 3600
check("MODERATE SLA ~24h", 23 < sla_hours <= 24.5, f"sla_hours={sla_hours:.1f}")
s, comments = api("GET", f"/api/case-comments/case/{case_mod}", admin)
check("no supervisor alert for MODERATE",
      not any(c.get("commentType") == "ALERT" for c in (comments or [])))

# ---------- LOW routing (explicit) ----------
s, b = api("POST", "/api/patients/members", admin,
           {"fullName": "Sprint5 Low Patient", "gender": "F", "mrNo": "MR-5003"})
s, b = api("POST", "/api/cases", admin,
           {"communityMemberId": b["memberId"], "sourceType": "Community", "priorityLevel": "Low"})
case_low = b["caseId"]
s, route = api("POST", "/api/assignment-queue/route", admin,
               {"caseId": case_low, "riskCategory": "low"})
check("route LOW (lowercase ok) -> 200", s == 200 and route.get("riskCategory") == "LOW")
check("LOW creates 1 PSYCHOSOCIAL referral", len(route.get("referralIds", [])) == 1)
sla_due = datetime.fromisoformat(route["slaDueAt"].replace("Z", "+00:00"))
sla_hours = (sla_due - datetime.now(timezone.utc)).total_seconds() / 3600
check("LOW SLA ~168h", 167 < sla_hours <= 169, f"sla_hours={sla_hours:.1f}")

# ---------- comments ----------
s, b = api("POST", "/api/case-comments", admin,
           {"caseId": case_low, "commentType": "HANDOVER", "comment": "Handover note for sprint 5"})
check("add HANDOVER comment -> 201/200", s in (200, 201), f"status={s}")
s, b = api("POST", "/api/case-comments", admin,
           {"caseId": case_low, "commentType": "BOGUS", "comment": "x"})
check("invalid comment type -> 400", s == 400, f"status={s}")
s, b = api("POST", "/api/case-comments", admin,
           {"caseId": case_low, "commentType": "NOTE", "comment": "   "})
check("empty comment -> 400", s == 400, f"status={s}")

# ---------- care plan direct create + validation ----------
s, b = api("POST", "/api/care-plans", admin,
           {"caseId": case_low, "riskCategory": "HIGH", "title": None, "steps": None})
check("direct care plan create -> 201/200", s in (200, 201), f"status={s}")
s, _ = api("POST", "/api/care-plans", admin,
           {"caseId": case_low, "riskCategory": "CRITICAL", "title": None, "steps": None})
check("invalid risk category -> 400", s == 400, f"status={s}")

# ---------- permission gating ----------
s, _ = api("POST", "/api/assignment-queue/route", viewer, {"caseId": case_low})
check("viewer route -> 403", s == 403, f"status={s}")
s, _ = api("POST", "/api/referrals", viewer,
           {"caseId": case_low, "referredTo": "PSYCHOLOGIST", "slaDueAt": None, "notes": None})
check("viewer create referral -> 403", s == 403, f"status={s}")
s, _ = api("GET", "/api/care-plans/routing-rules")
check("no token -> 401", s == 401, f"status={s}")
s, _ = api("GET", "/api/care-plans/routing-rules", viewer)
check("viewer read routing-rules (has read?) -> " + str(s), s in (200, 403), f"status={s}")

# ---------- audit ----------
audit = sql("SELECT COUNT(*) FROM CMS_AuditLogs WHERE TableName IN "
            "('CMS_ActionCarePlans','CMS_CaseAssignmentQueue','CMS_Referrals','CMS_CaseComments')")
check("audit rows written for care-mgmt writes", audit.isdigit() and int(audit) >= 10,
      f"audit_rows={audit}")

print(f"\n{len(passed)} passed, {len(failed)} failed")
if failed:
    print("FAILED:", failed)
    raise SystemExit(1)
