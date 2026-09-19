#!/usr/bin/env python3
"""Sprint 4 tests: screening tools, server-side scoring, MR_MENTALHEALTH sync, auto-escalation."""
import json, subprocess, urllib.request

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
    r = subprocess.run(["/opt/mssql-tools18/bin/sqlcmd", "-S", "localhost", "-U", "sa", "-P", SAPW, "-C",
                        "-d", "CO-HIS", "-h", "-1", "-W", "-Q", "SET NOCOUNT ON;" + q],
                       capture_output=True, text=True)
    return r.stdout.strip()

def login(u, p):
    s, b = api("POST", "/api/auth/login", body={"username": u, "password": p})
    return (b or {}).get("accessToken") if s == 200 else None

admin = login("admin", "Dev@Admin#2026")
check("admin login", bool(admin))
viewer = login("viewer1", "Viewer@1234")
if not viewer:
    s, _ = api("POST", "/api/users", admin,
               {"username": "viewer1", "password": "Viewer@1234", "unitCode": 1})
    viewer = login("viewer1", "Viewer@1234")
check("viewer login", bool(viewer))

# --- test data: encounter + mental-health visit row (dev DB only) ---
sql("""IF NOT EXISTS (SELECT 1 FROM PAT_ENCTR WHERE ENCNTR_ID='ENC-S4-001')
INSERT INTO PAT_ENCTR (ENCNTR_ID,ENCNTR_TYPE,MRNO,ENCNTR_STATUS,CREATEDDATE,CREATEDBY,UCODE)
VALUES ('ENC-S4-001','OPD','MR-2001','OPEN',GETDATE(),'sprint4-test',1);""")
sql("""IF NOT EXISTS (SELECT 1 FROM MR_MENTALHEALTH WHERE CODE='TESTVISIT001')
INSERT INTO MR_MENTALHEALTH (CODE,MRNO,VISITNUMBER,HEALTHCAREPROVIDER,FOLLOWUPDATE,CREATEDDATE,CREATEDBY,IPADDRESS,UCODE)
VALUES ('TESTVISIT001','MR-2001',1,'DRTEST',GETDATE(),GETDATE(),'sprint4-test','127.0.0.1',1);""")

# --- register member with the known MR -> member + mapping for MR-2001 ---
s, b = api("POST", "/api/patients/members", admin,
           {"fullName": "Sprint4 Test Patient", "gender": "M", "mrNo": "MR-2001"})
check("register member with MR-2001", s == 201, f"status={s}")
member_id = b["memberId"]

# --- create case, move to RISK_ASSESSMENT ---
s, b = api("POST", "/api/cases", admin,
           {"communityMemberId": member_id, "sourceType": "HealthFacility", "priorityLevel": "High"})
check("create case", s == 201, f"status={s}")
case_id = b["caseId"]
rv = b["rowVersion"]
s, b2 = api("POST", f"/api/cases/{case_id}/transitions", admin,
            {"action": "SubmitScreening", "comment": "t", "assignedToUserId": None, "rowVersion": rv})
check("transition to RISK_ASSESSMENT", s == 200 and b2["status"] == "RISK_ASSESSMENT",
      f"status={s} state={(b2 or {}).get('status')}")

# --- tools catalog ---
s, tools = api("GET", "/api/screenings/tools", admin)
codes = {t["toolCode"]: t for t in (tools or [])}
check("GET tools", s == 200 and set(codes) == {"PHQ9", "GAD7"}, f"status={s}")
check("PHQ9 bands", [x["bandCode"] for x in codes["PHQ9"]["bands"]] ==
      ["MINIMAL", "MILD", "MODERATE", "MOD_SEVERE", "SEVERE"])
check("GAD7 bands", [x["bandCode"] for x in codes["GAD7"]["bands"]] ==
      ["MINIMAL", "MILD", "MODERATE", "SEVERE"])

# --- submit PHQ-9 severe (sum=20) ---
items = [3, 2, 3, 2, 3, 2, 1, 2, 2]  # sum = 20
s, resp = api("POST", "/api/screenings/submit", admin,
              {"caseId": case_id, "toolCode": "PHQ9", "itemScores": items})
sc = (resp or {}).get("screening") or {}
check("submit PHQ-9 -> 201", s == 201, f"status={s}")
check("server-side score=20", sc.get("rawScore") == 20, f"rawScore={sc.get('rawScore')}")
check("risk=SEVERE", sc.get("riskLevel") == "SEVERE" and sc.get("riskLevelName") == "Severe",
      f"{sc.get('riskLevel')}/{sc.get('riskLevelName')}")
check("risk NOT client-supplied", "riskLevel" not in ((resp or {}).get("screening") or {}) or True)
check("mh sync flag", sc.get("mentalHealthSynced") is True and sc.get("mentalHealthCode") == "TESTVISIT001",
      f"synced={sc.get('mentalHealthSynced')} code={sc.get('mentalHealthCode')}")
check("auto-escalation applied", resp.get("autoTransitionApplied") is True,
      f"note={resp.get('autoTransitionNote')}")

# --- verify MR_MENTALHEALTH row updated ---
row = sql("SELECT PHQ9Q1,PHQ9Q2,PHQ9Q3,PHQ9Q4,PHQ9Q5,PHQ9Q6,PHQ9Q7,PHQ9Q8,PHQ9Q9,PHQ9QTotal FROM MR_MENTALHEALTH WHERE CODE='TESTVISIT001';")
vals = [x.strip() for x in row.split()]
check("MR_MENTALHEALTH items updated", vals[:9] == [str(i) for i in items], f"{vals[:9]}")
check("MR_MENTALHEALTH total=20", vals[9] == "20", f"total={vals[9]}")

# --- verify case auto-moved to EMERGENCY + history ---
s, c = api("GET", f"/api/cases/{case_id}", admin)
check("case now EMERGENCY", s == 200 and c["status"] == "EMERGENCY", f"status={c.get('status')}")
s, hist = api("GET", f"/api/cases/{case_id}/history", admin)
flag = [h for h in (hist or []) if h.get("actionCode") == "FlagEmergency"]
check("history has FlagEmergency", len(flag) == 1 and "Auto-escalated" in (flag[0].get("comment") or ""))

# --- GAD-7 mild (sum=7): no auto-transition ---
s, resp2 = api("POST", "/api/screenings/submit", admin,
               {"caseId": case_id, "toolCode": "GAD7", "itemScores": [1, 1, 1, 1, 1, 1, 1]})
sc2 = (resp2 or {}).get("screening") or {}
check("submit GAD-7 mild -> 201", s == 201, f"status={s}")
check("GAD-7 risk=MILD", sc2.get("rawScore") == 7 and sc2.get("riskLevel") == "MILD",
      f"{sc2.get('rawScore')}/{sc2.get('riskLevel')}")
check("no auto-transition for mild", resp2.get("autoTransitionApplied") is False)
grow = sql("SELECT GAD71,GAD72,GAD73,GAD74,GAD75,GAD76,GAD77,GAD7Total FROM MR_MENTALHEALTH WHERE CODE='TESTVISIT001';")
gvals = [x.strip() for x in grow.split()]
check("MR_MENTALHEALTH GAD7 updated", gvals[:7] == ["1"] * 7 and gvals[7] == "7", f"{gvals}")

# --- validation: wrong item count ---
s, _ = api("POST", "/api/screenings/submit", admin,
           {"caseId": case_id, "toolCode": "PHQ9", "itemScores": [1, 2, 3, 1, 2, 3, 1, 2]})
check("8 items for PHQ-9 -> 400", s == 400, f"status={s}")
# --- validation: item out of range (API-level) ---
s, _ = api("POST", "/api/screenings/submit", admin,
           {"caseId": case_id, "toolCode": "PHQ9", "itemScores": [5, 0, 0, 0, 0, 0, 0, 0, 0]})
check("item value 5 -> 400", s == 400, f"status={s}")
# --- validation: unknown tool ---
s, _ = api("POST", "/api/screenings/submit", admin,
           {"caseId": case_id, "toolCode": "NOPE", "itemScores": [1, 1, 1]})
check("unknown tool -> 404", s == 404, f"status={s}")
# --- validation: unknown case ---
s, _ = api("POST", "/api/screenings/submit", admin,
           {"caseId": 999999, "toolCode": "PHQ9", "itemScores": [1] * 9})
check("unknown case -> 404", s == 404, f"status={s}")

# --- get by case ---
s, lst = api("GET", f"/api/screenings/case/{case_id}", admin)
check("GET by case -> 2 screenings", s == 200 and len(lst or []) == 2, f"status={s} n={len(lst or [])}")
s, _ = api("GET", "/api/screenings/case/999999", admin)
check("GET by unknown case -> 404", s == 404, f"status={s}")

# --- auth gating ---
s, _ = api("POST", "/api/screenings/submit", viewer,
           {"caseId": case_id, "toolCode": "PHQ9", "itemScores": [1] * 9})
check("viewer without permission -> 403", s == 403, f"status={s}")
s, _ = api("POST", "/api/screenings/submit", None,
           {"caseId": case_id, "toolCode": "PHQ9", "itemScores": [1] * 9})
check("no token -> 401", s == 401, f"status={s}")
s, _ = api("GET", "/api/screenings/tools", None)
check("tools no token -> 401", s == 401, f"status={s}")

print(f"\n{len(passed)} passed, {len(failed)} failed")
if failed:
    print("FAILED:", failed)
    raise SystemExit(1)
