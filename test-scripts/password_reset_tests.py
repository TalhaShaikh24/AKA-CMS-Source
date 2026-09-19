#!/usr/bin/env python3
"""Password-reset (forgot/reset) end-to-end test suite.

Flow under test:
  POST /api/auth/forgot-password -> reset link (SMTP not configured in dev,
  so the service logs the link; the test extracts the raw token from the API
  log file) -> POST /api/auth/reset-password -> login with new password.

Run the API first with stdout/stderr redirected to the log file passed as
argv[1] (default /tmp/aka-api.log).
"""
import json, re, sys, urllib.request, urllib.error

BASE = "http://localhost:5000"
LOG = sys.argv[1] if len(sys.argv) > 1 else "/tmp/aka-api.log"
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
    if s == 200:
        return s, d["accessToken"], d["refreshToken"]
    return s, None, None

def token_from_log(email):
    with open(LOG, errors="ignore") as f:
        text = f.read()
    # last logged reset link for this e-mail
    for m in reversed(list(re.finditer(
            r"password reset link for " + re.escape(email) + r": (\S+)", text))):
        url = m.group(1)
        tm = re.search(r"token=([A-Za-z0-9\-_]+)", url)
        if tm:
            return tm.group(1)
    return None

# --- setup: admin login ---
s, admin_tok, _ = login("admin", "Dev@Admin#2026")
check("admin login 200", s == 200)
if s != 200:
    print(f"TOTAL: {len(passed)} passed, {len(failed)} failed"); sys.exit(1)

# --- create a test user WITH an e-mail ---
uname = "pwreset_tester"
s, u = req("POST", "/api/users",
    {"username": uname, "password": "OldPass@123",
     "email": "pwreset.tester@example.local", "roleIds": [2]}, admin_tok)
check("create user with email 201", s == 201, f"({(u or {}).get('userId')})")
uid = u["userId"]
check("user dto carries email", u.get("email") == "pwreset.tester@example.local")

s, g = req("GET", f"/api/users/{uid}", token=admin_tok)
check("get user shows email", s == 200 and g.get("email") == "pwreset.tester@example.local")

# login as the test user -> active session to prove revocation later
s, _, old_refresh = login(uname, "OldPass@123")
check("test user login with old password 200", s == 200)

# --- forgot-password: valid e-mail ---
s, d = req("POST", "/api/auth/forgot-password",
    {"email": "pwreset.tester@example.local"})
check("forgot-password known email 200", s == 200)
check("forgot-password generic message", s == 200 and
      "reset" in (d.get("message") or "").lower())

raw_token = token_from_log("pwreset.tester@example.local")
check("reset link logged with token", raw_token is not None)

# --- forgot-password: unknown e-mail must NOT reveal absence ---
s, d2 = req("POST", "/api/auth/forgot-password",
    {"email": "nobody-here-xyz@example.local"})
check("forgot-password unknown email 200", s == 200)
check("forgot-password unknown email same message",
      (d2 or {}).get("message") == (d or {}).get("message"))

# --- forgot-password: bad e-mail -> 400 ---
s, _ = req("POST", "/api/auth/forgot-password", {"email": "not-an-email"})
check("forgot-password invalid email 400", s == 400)

# --- reset-password: happy path ---
s, r = req("POST", "/api/auth/reset-password",
    {"token": raw_token, "newPassword": "NewPass@456"})
check("reset-password valid token 200", s == 200)

# --- token is single-use ---
s, _ = req("POST", "/api/auth/reset-password",
    {"token": raw_token, "newPassword": "Another@789"})
check("reset-password token reuse -> 401", s == 401)

# --- login behaviour after reset ---
s, new_tok, _ = login(uname, "NewPass@456")
check("login with new password 200", s == 200)
s, _, _ = login(uname, "OldPass@123")
check("login with old password -> 401", s == 401)

# --- old refresh token revoked by the reset ---
s, _ = req("POST", "/api/auth/refresh", {"refreshToken": old_refresh})
check("old refresh token revoked -> 401", s == 401)

# --- reset-password: bogus token ---
s, _ = req("POST", "/api/auth/reset-password",
    {"token": "definitely-not-a-real-token", "newPassword": "NewPass@456"})
check("reset-password bogus token -> 401", s == 401)

# --- reset-password: short password -> 400 ---
s, _ = req("POST", "/api/auth/reset-password",
    {"token": raw_token, "newPassword": "short"})
check("reset-password short password 400", s == 400)

# --- duplicate e-mail must conflict ---
s, _ = req("POST", "/api/users",
    {"username": "pwreset_dup", "password": "Dup@12345",
     "email": "pwreset.tester@example.local", "roleIds": [2]}, admin_tok)
check("create user with duplicate email -> 409", s == 409)

print(f"TOTAL: {len(passed)} passed, {len(failed)} failed")
sys.exit(1 if failed else 0)
