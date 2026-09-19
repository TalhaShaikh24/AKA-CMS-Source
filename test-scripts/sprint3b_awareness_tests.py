#!/usr/bin/env python3
"""Sprint 3b tests: Module 1 remainder — AwarenessSessions, SessionParticipants,
CaseSourceMapping.

Covers: awareness session create (201, auto SessionCode SES-YYYY-######),
list with filters (200), get-by-id with participants (200), participant
registration — registered member (201), idempotent re-registration (200),
walk-in by name (201), RowVersion update (200) + stale (409), validation
(400), case-source recording — auto on case creation, manual POST (201),
duplicate (409), invalid type (400), missing case (404), source-types
client-sourcing flags, permission gating (403), auth (401), audit rows.

Prerequisites: CO-HIS restored, all CMS schema/proc files applied
(01_Schema/02..15, 02_StoredProcedures/01..11), API on http://localhost:5000.
"""
import json, re, urllib.request, urllib.error, subprocess

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

# limited user with no awareness/case-source permissions (for 403 tests)
s, _ = api("POST", "/api/users", admin,
           {"username": "viewer3", "password": "Viewer@1234", "unitCode": 1})
viewer = login("viewer3", "Viewer@1234")
check("viewer login", bool(viewer))

# ---------- create awareness session ----------
session_req = {
    "title": "Sprint3b Community Awareness Session",
    "facilityCode": "GB-GLT-01",
    "sessionDate": "2026-09-10",
    "conductedBy": None,
    "topic": "Mental health literacy",
    "targetGroup": "Community elders",
    "venue": "Community hall",
    "maleCount": 12, "femaleCount": 18, "otherCount": 0,
    "notes": "test session"
}
s, b = api("POST", "/api/awareness-sessions", admin, session_req)
session = (b or {}).get("session") or {}
session_id = session.get("sessionId")
code_ok = bool(re.fullmatch(r"SES-\d{4}-\d{6}", session.get("sessionCode") or ""))
check("POST awareness session -> 201", s == 201, f"status={s}")
check("auto SessionCode SES-YYYY-######", code_ok, session.get("sessionCode"))
check("session detail has empty participants", (b or {}).get("participants") == [])

# ---------- get by id ----------
s, b = api("GET", f"/api/awareness-sessions/{session_id}", admin)
check("GET session by id -> 200", s == 200 and (b or {}).get("session", {}).get("title") == session_req["title"])

# ---------- list + filters ----------
s, lst = api("GET", "/api/awareness-sessions", admin)
check("GET sessions list -> 200", s == 200 and any(x["sessionId"] == session_id for x in (lst or [])))
s, lst = api("GET", "/api/awareness-sessions?facilityCode=GB-GLT-01", admin)
check("list filtered by facilityCode -> 200", s == 200 and any(x["sessionId"] == session_id for x in (lst or [])))
s, lst = api("GET", "/api/awareness-sessions?facilityCode=NOPE-00", admin)
check("list filtered by unknown facility -> 200 []", s == 200 and not any(x["sessionId"] == session_id for x in (lst or [])))

# ---------- register a community member ----------
s, b = api("POST", "/api/patients/members", admin,
           {"fullName": "Sprint3b Awareness Attendee", "gender": "F", "mrNo": "MR-3B01"})
member_id = (b or {}).get("memberId")
check("setup: member created", bool(member_id))

# ---------- register participant (registered member) ----------
s, b = api("POST", f"/api/awareness-sessions/{session_id}/participants", admin,
           {"communityMemberId": member_id, "participantName": None,
            "attended": True, "consentedToScreening": True})
check("POST participant (member) -> 201", s == 201 and (b or {}).get("wasNew") is True,
      f"status={s} wasNew={(b or {}).get('wasNew')}")

# ---------- idempotent re-registration ----------
s, b = api("POST", f"/api/awareness-sessions/{session_id}/participants", admin,
           {"communityMemberId": member_id, "participantName": None,
            "attended": True, "consentedToScreening": True})
check("re-register same member -> 200 idempotent", s == 200 and (b or {}).get("wasNew") is False,
      f"status={s} wasNew={(b or {}).get('wasNew')}")

# ---------- register walk-in by name ----------
s, b = api("POST", f"/api/awareness-sessions/{session_id}/participants", admin,
           {"communityMemberId": None, "participantName": "Walk-in Guest",
            "attended": True, "consentedToScreening": False})
check("POST participant (walk-in name) -> 201", s == 201 and (b or {}).get("wasNew") is True,
      f"status={s}")

# ---------- session detail now has 2 participants ----------
s, b = api("GET", f"/api/awareness-sessions/{session_id}", admin)
parts = (b or {}).get("participants") or []
check("session detail participants = 2", s == 200 and len(parts) == 2, f"count={len(parts)}")
check("participant count on session", (b or {}).get("session", {}).get("participantCount") == 2)

# ---------- update session (RowVersion) ----------
s, b = api("GET", f"/api/awareness-sessions/{session_id}", admin)
rv = (b or {}).get("session", {}).get("rowVersion")
upd = dict(session_req); upd["title"] = "Sprint3b Session (updated)"; upd["rowVersion"] = rv
s, b = api("PATCH", f"/api/awareness-sessions/{session_id}", admin, upd)
check("PATCH session -> 200", s == 200 and (b or {}).get("session", {}).get("title") == upd["title"],
      f"status={s}")

# ---------- stale RowVersion -> 409 ----------
upd["title"] = "stale attempt"; upd["rowVersion"] = rv
s, _ = api("PATCH", f"/api/awareness-sessions/{session_id}", admin, upd)
check("PATCH stale RowVersion -> 409", s == 409, f"status={s}")

# ---------- validation 400s ----------
bad = dict(session_req); bad["title"] = ""
s, _ = api("POST", "/api/awareness-sessions", admin, bad)
check("POST session empty title -> 400", s == 400, f"status={s}")
s, _ = api("POST", f"/api/awareness-sessions/{session_id}/participants", admin,
           {"communityMemberId": None, "participantName": "  ",
            "attended": True, "consentedToScreening": False})
check("POST participant no member/name -> 400", s == 400, f"status={s}")
s, _ = api("POST", "/api/awareness-sessions/999999/participants", admin,
           {"communityMemberId": member_id, "participantName": None,
            "attended": True, "consentedToScreening": False})
check("POST participant missing session -> 404", s == 404, f"status={s}")

# ---------- auth / permission gating ----------
s, _ = api("POST", "/api/awareness-sessions", None, session_req)
check("POST session no token -> 401", s == 401, f"status={s}")
s, _ = api("GET", "/api/awareness-sessions", None)
check("GET sessions no token -> 401", s == 401, f"status={s}")
s, _ = api("POST", "/api/awareness-sessions", viewer, session_req)
check("POST session no permission -> 403", s == 403, f"status={s}")

# ---------- case creation auto-records source ----------
s, b = api("POST", "/api/patients/members", admin,
           {"fullName": "Sprint3b Source Case Patient", "gender": "M", "mrNo": "MR-3B02"})
member2 = (b or {}).get("memberId")
s, b = api("POST", "/api/cases", admin,
           {"communityMemberId": member2, "sourceType": "AwarenessSession",
            "priorityLevel": "Moderate", "notes": None, "sourceReferenceId": session_id})
case_id = (b or {}).get("caseId")
check("case created with AwarenessSession source -> 201", s == 201 and bool(case_id), f"status={s}")
s, m = api("GET", f"/api/cases/{case_id}/source", admin)
check("auto-recorded case source -> 200 AwarenessSession",
      s == 200 and (m or {}).get("sourceType") == "AwarenessSession"
      and (m or {}).get("sourceReferenceId") == session_id,
      f"status={s} body={m}")

# ---------- manual source record + duplicate 409 ----------
s, b = api("POST", "/api/patients/members", admin,
           {"fullName": "Sprint3b Manual Source Patient", "gender": "M", "mrNo": "MR-3B03"})
member3 = (b or {}).get("memberId")
s, b = api("POST", "/api/cases", admin,
           {"communityMemberId": member3, "sourceType": "Community",
            "priorityLevel": "Low", "notes": None})
case2 = (b or {}).get("caseId")
# delete the auto-recorded row so the manual path is exercised end-to-end
sql(f"DELETE FROM dbo.CMS_CaseSourceMapping WHERE CaseId = {case2}")
s, m = api("POST", f"/api/cases/{case2}/source", admin,
           {"sourceType": "Community", "sourceReferenceId": None})
check("POST case source manual -> 201", s == 201 and (m or {}).get("sourceType") == "Community",
      f"status={s}")
s, _ = api("POST", f"/api/cases/{case2}/source", admin,
           {"sourceType": "Community", "sourceReferenceId": None})
check("duplicate case source -> 409", s == 409, f"status={s}")
s, _ = api("POST", f"/api/cases/{case2}/source", admin,
           {"sourceType": "NoSuchSource", "sourceReferenceId": None})
check("invalid source type -> 400", s == 400, f"status={s}")
s, _ = api("POST", "/api/cases/999999/source", admin,
           {"sourceType": "Community", "sourceReferenceId": None})
check("source for missing case -> 400", s == 400, f"status={s}")
s, _ = api("GET", f"/api/cases/{case2}/source", viewer)
check("GET case source no permission -> 403", s == 403, f"status={s}")
s, _ = api("GET", f"/api/cases/{case2}/source", None)
check("GET case source no token -> 401", s == 401, f"status={s}")

# ---------- source types: client-sourcing flags ----------
flagged = sql("SELECT SourceTypeCode FROM dbo.CMS_CaseSourceTypes WHERE IsClientSourced = 0 AND IsActive = 1 ORDER BY SourceTypeCode")
check("WalkIn/Referral flagged non-client", "Referral" in flagged and "WalkIn" in flagged, flagged)
client = sql("SELECT COUNT(*) FROM dbo.CMS_CaseSourceTypes WHERE IsClientSourced = 1 AND IsActive = 1")
check("6 client-sourced types", client == "6", client)

# ---------- audit rows ----------
a1 = sql("SELECT COUNT(*) FROM dbo.CMS_AuditLogs WHERE TableName = 'CMS_AwarenessSessions'")
a2 = sql("SELECT COUNT(*) FROM dbo.CMS_AuditLogs WHERE TableName = 'CMS_SessionParticipants'")
a3 = sql("SELECT COUNT(*) FROM dbo.CMS_AuditLogs WHERE TableName = 'CMS_CaseSourceMapping'")
check("audit rows for sessions", a1.isdigit() and int(a1) >= 1, a1)
check("audit rows for participants", a2.isdigit() and int(a2) >= 1, a2)
check("audit rows for case sources", a3.isdigit() and int(a3) >= 1, a3)

print(f"\n{len(passed)} passed, {len(failed)} failed")
if failed:
    print("FAILED:", failed)
    raise SystemExit(1)
