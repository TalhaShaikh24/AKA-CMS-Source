#!/usr/bin/env python3
"""Sprint 8 tests: Notifications, Attachments, Audit logs, Sync outbox.

Covers: notification send/list/read/read-all with delivery status
changes; attachment upload/download roundtrip with correct
content-type; oversize/disallowed uploads rejected (400); attachment
listing; audit log filters + pagination; sync push idempotency (409
with the existing record); pull-since watermark returning only newer
changes; ack; server-wins conflict report; 401/403 gating; audit rows
for write ops. Existing CO-HIS tables are NOT touched.
"""
import json, urllib.request, urllib.error, urllib.parse, subprocess, time, os
from datetime import datetime, timezone, timedelta

BASE = "http://localhost:5000"
with open("AKA.CMS.API/appsettings.Development.json") as f:
    CS = json.load(f)["ConnectionStrings"]["DefaultConnection"]
SAPW = CS.split("Password=")[1].split(";")[0]
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

def raw(method, path, token=None, data=None, ctype=None):
    req = urllib.request.Request(BASE + path, method=method, data=data)
    if ctype:
        req.add_header("Content-Type", ctype)
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, r.read(), r.headers.get("Content-Type")
    except urllib.error.HTTPError as e:
        return e.code, e.read(), e.headers.get("Content-Type")

def multipart(fields, filename, filebytes, fieldname="file", mimetype="text/plain"):
    boundary = "BOUNDARY" + RUNID
    parts = []
    for k, v in fields.items():
        parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode())
    parts.append(
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"{fieldname}\"; filename=\"{filename}\"\r\n"
        f"Content-Type: {mimetype}\r\n\r\n".encode() + filebytes + f"\r\n--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"

def sql(q):
    r = subprocess.run(["/opt/mssql-tools18/bin/sqlcmd", "-S", "localhost", "-U", "sa",
                        "-P", SAPW, "-C", "-d", "CO-HIS", "-h", "-1", "-W",
                        "-Q", "SET NOCOUNT ON;" + q],
                       capture_output=True, text=True)
    return r.stdout.strip()

def login(u, p):
    s, b = api("POST", "/api/auth/login", body={"username": u, "password": p})
    return (b or {}).get("accessToken") if s == 200 else None

# ---------- CO-HIS baseline (existing tables must not change) ----------
# Taken after test-user creation, since creating a user legitimately
# writes to the pre-existing USERS table (sprint 0 pattern).
admin = login("admin", "Dev@Admin#2026")
check("admin login", bool(admin))

s, vu = api("POST", "/api/users", admin,
            {"username": f"viewer8_{RUNID}", "password": "Viewer@1234", "unitCode": 1})
viewer = login(f"viewer8_{RUNID}", "Viewer@1234")
check("viewer login (no new permissions)", bool(viewer))

cohis_before = sql("SELECT SUM(c) FROM (SELECT COUNT(*) c FROM USERS UNION ALL "
                   "SELECT COUNT(*) FROM ROLES UNION ALL SELECT COUNT(*) FROM PAT_ENCTR) t;")
cms_tables_before = sql("SELECT COUNT(*) FROM sys.tables WHERE name LIKE 'CMS\\_%' ESCAPE '\\';")

case_id = int(sql("SELECT TOP 1 CaseId FROM CMS_Cases WHERE IsActive=1 ORDER BY CaseId;"))
check("case available", case_id > 0)

# ---------- Notifications ----------
s, n = api("POST", "/api/notifications", admin,
           {"recipientUserId": int(sql("SELECT USERID FROM USERS WHERE USERNAME='admin';")),
            "title": f"Test notification {RUNID}", "body": "Body here.",
            "relatedCaseId": case_id, "pushPayload": "{\"aps\":{\"alert\":\"hi\"}}"})
check("send notification -> 201", s == 201, s)
nid = (n or {}).get("notificationId")

s, lst = api("GET", "/api/notifications", admin)
items = (lst or {}).get("items", [])
mine = [x for x in items if x.get("notificationId") == nid]
check("list notifications -> 200", s == 200 and len(mine) == 1, s)
check("new notification status Unread", bool(mine) and mine[0]["status"] == "Unread", mine[0].get("status") if mine else "")
check("push-ready payload stored", bool(mine) and mine[0].get("pushPayload") == "{\"aps\":{\"alert\":\"hi\"}}")

s, unread = api("GET", "/api/notifications?unreadOnly=true", admin)
check("unreadOnly filter includes new notification",
      s == 200 and any(x.get("notificationId") == nid for x in (unread or {}).get("items", [])), s)

s, _ = api("PATCH", f"/api/notifications/{nid}/read", admin)
check("mark as read -> 204", s == 204, s)

s, lst = api("GET", "/api/notifications?unreadOnly=false", admin)
read_one = next((x for x in (lst or {}).get("items", []) if x.get("notificationId") == nid), None)
check("status changed to Read", read_one is not None and read_one["status"] == "Read" and read_one["isRead"] is True,
      read_one.get("status") if read_one else "missing")

s, unread = api("GET", "/api/notifications?unreadOnly=true", admin)
check("read notification leaves unread list",
      s == 200 and not any(x.get("notificationId") == nid for x in (unread or {}).get("items", [])), s)

s, ra = api("POST", "/api/notifications/read-all", admin)
check("read-all -> 200 with count", s == 200 and isinstance((ra or {}).get("markedCount"), int), s)

s, _ = api("PATCH", "/api/notifications/999999999/read", admin)
check("read missing notification -> 404", s == 404, s)

s, _ = api("GET", "/api/notifications")
check("notifications 401 without token", s == 401, s)
s, _ = api("GET", "/api/notifications", viewer)
check("notifications 403 for viewer", s == 403, s)
s, _ = api("PATCH", f"/api/notifications/{nid}/read", viewer)
check("read 403 for viewer", s == 403, s)

# ---------- Attachments ----------
payload = b"hello attachment " + RUNID.encode()
body, ctype = multipart({"caseId": str(case_id)}, "report.txt", payload)
s, rawb, rct = raw("POST", "/api/case-attachments", admin, body, ctype)
up = json.loads(rawb.decode() or "null")
check("upload -> 201", s == 201, s)
aid = (up or {}).get("attachmentId")

s, lst = api("GET", f"/api/cases/{case_id}/attachments", admin)
alist = lst if isinstance(lst, list) else []
check("attachment listed for case",
      s == 200 and any(x.get("attachmentId") == aid for x in alist), s)

s, data, dct = raw("GET", f"/api/case-attachments/{aid}/download", admin)
check("download -> 200 with correct content-type",
      s == 200 and dct and dct.startswith("text/plain"), f"{s} {dct}")
check("download bytes match", data == payload)

# temporarily shrink the size limit so we don't need an 11MB upload
sql("UPDATE CMS_SystemSettings SET SettingValue='10' WHERE SettingKey='Attachments.MaxAttachmentBytes';")
body, ctype = multipart({"caseId": str(case_id)}, "big.txt", b"x" * 100)
s, rawb, _ = raw("POST", "/api/case-attachments", admin, body, ctype)
check("oversize upload -> 400", s == 400, s)
sql("UPDATE CMS_SystemSettings SET SettingValue='10485760' WHERE SettingKey='Attachments.MaxAttachmentBytes';")
s2 = sql("SELECT SettingValue FROM CMS_SystemSettings WHERE SettingKey='Attachments.MaxAttachmentBytes';")
check("size limit restored", s2 == "10485760", s2)

body, ctype = multipart({"caseId": str(case_id)}, "evil.exe", b"MZ", mimetype="application/octet-stream")
s, rawb, _ = raw("POST", "/api/case-attachments", admin, body, ctype)
check("disallowed type -> 400", s == 400, s)

body, ctype = multipart({"caseId": "999999999"}, "orphan.txt", b"no case")
s, rawb, _ = raw("POST", "/api/case-attachments", admin, body, ctype)
check("upload to missing case -> 404", s == 404, s)

s, _, _ = raw("GET", "/api/case-attachments/999999999/download", admin)
check("download missing -> 404", s == 404, s)

s, _, _ = raw("GET", f"/api/cases/{case_id}/attachments", viewer)
check("attachment list 403 for viewer", s == 403, s)
body, ctype = multipart({"caseId": str(case_id)}, "no.txt", b"no")
s, _, _ = raw("POST", "/api/case-attachments", viewer, body, ctype)
check("upload 403 for viewer", s == 403, s)
s, _, _ = raw("GET", f"/api/cases/{case_id}/attachments")
check("attachment list 401 without token", s == 401, s)

# ---------- Audit logs ----------
s, q = api("GET", "/api/audit-logs", admin)
check("audit query -> 200", s == 200, s)
check("audit rows present", (q or {}).get("totalCount", 0) > 0, (q or {}).get("totalCount"))

s, q = api("GET", "/api/audit-logs?tableName=CMS_Notifications", admin)
check("audit filter tableName", s == 200 and all(
    x["tableName"] == "CMS_Notifications" for x in q.get("items", [])), s)

s, q = api("GET", f"/api/audit-logs?tableName=CMS_CaseAttachments&recordId={aid}", admin)
check("audit filter recordId", s == 200 and any(
    x["recordId"] == str(aid) for x in q.get("items", [])), s)

s, q = api("GET", "/api/audit-logs?page=1&pageSize=5", admin)
check("audit pagination page 1", s == 200 and len(q.get("items", [])) <= 5 and q.get("totalCount", 0) > 5, s)
s, q2 = api("GET", "/api/audit-logs?page=2&pageSize=5", admin)
ids1 = {x["id"] for x in q.get("items", [])}
ids2 = {x["id"] for x in (q2 or {}).get("items", [])}
check("audit pagination pages differ", s == 200 and ids1 and not (ids1 & ids2))

since_raw = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
since = urllib.parse.quote(since_raw)
s, q = api("GET", f"/api/audit-logs?fromDate={since}", admin)
check("audit fromDate filter", s == 200 and all(
    x["performedAt"] >= since_raw[:19] for x in q.get("items", [])), s)
s, q = api("GET", f"/api/audit-logs?toDate={since}", admin)
check("audit toDate filter", s == 200 and all(
    x["performedAt"] <= since_raw[:19] for x in q.get("items", [])), s)

s, _ = api("GET", "/api/audit-logs", viewer)
check("audit 403 for viewer", s == 403, s)
s, _ = api("GET", "/api/audit-logs")
check("audit 401 without token", s == 401, s)

# ---------- Sync ----------
watermark_raw = (datetime.now(timezone.utc) - timedelta(minutes=2)).isoformat()
watermark = urllib.parse.quote(watermark_raw)
key1 = f"key-{RUNID}-1"
push = {"idempotencyKey": key1, "deviceId": "dev-1", "entityType": "CMS_CaseComments",
        "entityId": None, "action": "CREATE",
        "payloadJson": "{\"comment\":\"offline note\"}", "baseVersion": None}
s, r1 = api("POST", "/api/sync/push", admin, push)
check("sync push -> 200 Applied", s == 200 and (r1 or {}).get("status") == "Applied", f"{s} {(r1 or {}).get('status')}")
oid = (r1 or {}).get("outboxId")

s, r2 = api("POST", "/api/sync/push", admin, push)
check("duplicate key -> 409 with existing record",
      s == 409 and (r2 or {}).get("isDuplicate") is True and (r2 or {}).get("outboxId") == oid,
      f"{s} {(r2 or {}).get('outboxId')}")

key2 = f"key-{RUNID}-2"
old_base_raw = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()
old_base = old_base_raw
push2 = {"idempotencyKey": key2, "deviceId": "dev-1", "entityType": "CMS_Cases",
         "entityId": case_id, "action": "UPDATE",
         "payloadJson": "{\"note\":\"stale\"}", "baseVersion": old_base_raw}
s, r3 = api("POST", "/api/sync/push", admin, push2)
check("conflicting push -> Conflict with report",
      s == 200 and (r3 or {}).get("status") == "Conflict" and (r3 or {}).get("conflictReportJson"),
      f"{s} {(r3 or {}).get('status')}")

key3 = f"key-{RUNID}-3"
push3 = {"idempotencyKey": key3, "deviceId": "dev-1", "entityType": "CMS_Cases",
         "entityId": case_id, "action": "UPDATE",
         "payloadJson": "{\"note\":\"fresh\"}",
         "baseVersion": (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat()}
s, r4 = api("POST", "/api/sync/push", admin, push3)
check("fresh push -> Applied", s == 200 and (r4 or {}).get("status") == "Applied", s)

bad = dict(push, idempotencyKey=f"key-{RUNID}-bad", action="BOGUS")
s, _ = api("POST", "/api/sync/push", admin, bad)
check("sync push invalid action -> 400", s == 400, s)

s, pull = api("GET", f"/api/sync/pull?since={watermark}&pageSize=500", admin)
items = (pull or {}).get("items", [])
check("pull -> 200 newer changes only",
      s == 200 and items and all(x["changedAt"] > watermark_raw[:19] for x in items), f"{s} {len(items)}")
check("pull returns new watermark", (pull or {}).get("watermark", "") >= watermark_raw[:19])
check("pull includes the pushes", any("CMS_SyncOutbox" == x["entityType"] for x in items))

future = urllib.parse.quote((datetime.now(timezone.utc) + timedelta(hours=1)).isoformat())
s, pull2 = api("GET", f"/api/sync/pull?since={future}", admin)
check("pull future watermark -> empty", s == 200 and (pull2 or {}).get("items") == [], s)

s, a = api("POST", "/api/sync/ack", admin, {"idempotencyKey": key1, "deviceId": "dev-1"})
check("ack -> 200", s == 200 and (a or {}).get("acknowledged") is True, s)
st = sql(f"SELECT Status FROM CMS_SyncOutbox WHERE IdempotencyKey='{key1}';")
check("ack status persisted", st == "Acked", st)

s, _ = api("POST", "/api/sync/ack", admin, {"idempotencyKey": "nope", "deviceId": "dev-1"})
check("ack missing key -> 404", s == 404, s)

s, _ = api("POST", "/api/sync/push", admin, push)
check("duplicate after ack still -> 409", s == 409, s)

s, _ = api("POST", "/api/sync/push", viewer, push)
check("sync push 403 for viewer", s == 403, s)
s, _ = api("GET", f"/api/sync/pull?since={watermark}")
check("sync pull 401 without token", s == 401, s)

# ---------- Audit rows written by sprint-8 write paths ----------
n_audit = sql("SELECT COUNT(*) FROM CMS_AuditLogs WHERE TableName IN "
              "('CMS_Notifications','CMS_CaseAttachments','CMS_SyncOutbox');")
check("audit rows for sprint-8 tables", int(n_audit) >= 5, n_audit)

# ---------- CO-HIS untouched ----------
cohis_after = sql("SELECT SUM(c) FROM (SELECT COUNT(*) c FROM USERS UNION ALL "
                  "SELECT COUNT(*) FROM ROLES UNION ALL SELECT COUNT(*) FROM PAT_ENCTR) t;")
cms_tables_after = sql("SELECT COUNT(*) FROM sys.tables WHERE name LIKE 'CMS\\_%' ESCAPE '\\';")
new_tables = sql("SELECT COUNT(*) FROM sys.tables WHERE name IN ('CMS_CaseAttachments','CMS_SyncOutbox');")
check("existing CO-HIS tables unchanged", cohis_after == cohis_before, f"{cohis_before}->{cohis_after}")
check("sprint-8 CMS_ tables present, none added during run",
      new_tables == "2" and cms_tables_after == cms_tables_before, f"{cms_tables_before}->{cms_tables_after}")

print(f"\n{len(passed)} passed, {len(failed)} failed")
if failed:
    print("FAILED:", failed)
    raise SystemExit(1)
