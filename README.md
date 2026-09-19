# AKA-CMS — Backend API

ASP.NET Core 8 Web API + Dapper + Stored Procedures (SQL Server), Clean Architecture.
Case-management system for Aga Khan University (IMHP-CMS). **Backend only** — the
Flutter app is built by a separate developer against this API contract
(see `docs/API_INVENTORY.md` and the Swagger UI).

> **Status:** Sprints 0–10 complete. Full regression: **408/408 green**.

---

## 1. Prerequisites

| Tool | Version |
|---|---|
| .NET SDK | 8.x (`dotnet --version`) |
| SQL Server | 2019+ (2022 used in dev), with `sqlcmd` |
| Python | 3.9+ (regression tests only) |

No EF Core, no code-first migrations — the database is managed with plain `.sql`
scripts under `database/`.

---

## 2. Database setup

The API runs against a database named **`CO-HIS`** (a copy of the hospital's
existing HIS database). All CMS tables are `CMS_`-prefixed; **existing CO-HIS
tables are never altered** — CMS code only *reads* `USERS`, `ROLES`, `USER_ROLE`,
`ROLESACTIONMAPPING`, `AllCONTROLLERS`, `MR_MENTALHEALTH`, `UNIT`.

### 2a. Restore / create CO-HIS

Restore your CO-HIS backup as database `CO-HIS` (or create an empty database
with that name for a green-field setup). Then apply the scripts **in order**:

**Schema + seed** (`database/01_Schema/`, in filename order):

```
02_CMS_Extensions.sql        13_CMS_HelplineCrisisSeed.sql
03_CMS_Seed.sql              14_CMS_Awareness.sql
04_CMS_Patients.sql          15_CMS_AwarenessSeed.sql
05_CMS_PatientSeed.sql       16_CMS_Treatment.sql
06_CMS_Cases.sql             17_CMS_TreatmentSeed.sql
07_CMS_CaseSeed.sql          18_CMS_FollowUpClosure.sql
08_CMS_Screenings.sql        19_CMS_FollowUpClosureSeed.sql
09_CMS_ScreeningSeed.sql     20_CMS_Sync.sql
10_CMS_CareManagement.sql    21_CMS_SyncSeed.sql
11_CMS_CareManagementSeed.sql 22_CMS_Sprint9.sql
12_CMS_HelplineCrisis.sql    23_CMS_Sprint9Seed.sql
```

**Stored procedures** (`database/02_StoredProcedures/`, in filename order):

```
01_Auth.sql                  09_CareManagement.sql
02_Users.sql                 10_HelplineCrisis.sql
03_Roles.sql                 11_AwarenessSessions.sql
04_Permissions.sql           12_Treatment.sql
05_RoleCreate.sql            13_FollowUpClosure.sql
06_Patients.sql              14_NotificationsAttachmentsSync.sql
07_Cases.sql                 15_MasterDataReports.sql
08_Screenings.sql            16_Health.sql
```

Apply with sqlcmd, e.g.:

```bash
for f in database/01_Schema/*.sql database/02_StoredProcedures/*.sql; do
  sqlcmd -S localhost -U sa -P '<SA_PASSWORD>' -d CO-HIS -i "$f"
done
```

(Files sort alphabetically = dependency order.)

### 2b. Local SQL Server (dev VM)

```bash
./start-sqlserver.sh        # starts the local SQL Server 2022 container/instance
```

---

## 3. Configuration

Copy and edit the dev settings (never commit real secrets):

`AKA.CMS.API/appsettings.Development.json`

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Database=CO-HIS;User Id=sa;Password=<SA_PASSWORD>;TrustServerCertificate=True;"
  },
  "Jwt": {
    "Issuer": "aka-cms",
    "Audience": "aka-cms-clients",
    "SigningKey": "<AT_LEAST_32_CHAR_RANDOM_KEY>",
    "AccessTokenMinutes": 60,
    "RefreshTokenDays": 7
  },
  "FileStorage": { "RootPath": "<repo>/uploads", "MaxBytes": 10485760 }
}
```

- Seeded admin for first login: `admin` (password is set in `03_CMS_Seed.sql` —
  change it immediately).
- File uploads land under `uploads/` (git-ignored content; 10 MB provisional limit).

---

## 4. Run the API

```bash
dotnet build AKA.CMS.sln          # 0 warnings, 0 errors expected
cd AKA.CMS.API
ASPNETCORE_ENVIRONMENT=Development dotnet run --urls http://localhost:5000
```

- Swagger UI: `http://localhost:5000/swagger` (Development only — the contract
  document for the Flutter developer).
- Health: `GET http://localhost:5000/api/health` → `200 {"status":"Healthy",...}`
  (anonymous; `503` when the DB is unreachable).
- Login: `POST /api/auth/login` `{"username":"admin","password":"..."}` →
  `{accessToken, refreshToken, ...}`; pass `Authorization: Bearer <accessToken>`.

### Hardening (Sprint 10)

- RFC 7807 `ProblemDetails` for all errors (400 validation / 401 / 403 / 404 /
  409 concurrency / 500), with `X-Correlation-Id` echoed in the payload and logs.
- Rate limiting on auth endpoints: 60 req/min/IP, fixed window (**provisional** —
  see open items).
- Security headers: `X-Content-Type-Options`, `X-Frame-Options: DENY`,
  `Referrer-Policy`, `Permissions-Policy`, HSTS outside Development.
- Every paginated endpoint returns the same envelope:
  `{items, totalCount, page, pageSize}` (`PagedResult<T>`).

---

## 5. Run the tests

The regression suite is Python + stdlib only, hitting the **running API**:

```bash
# API must be up on http://localhost:5000 first
for t in test-scripts/sprint*_tests.py; do python3 "$t"; done
```

| Suite | Tests | Covers |
|---|---|---|
| `sprint3_tests.py` | 42 | Workflow engine (cases, transitions, history) |
| `sprint3b_awareness_tests.py` | 36 | Awareness sessions, participants, case sources |
| `sprint4_tests.py` | 31 | PHQ-9/GAD-7 screening + risk stratification |
| `sprint4b_helpline_tests.py` | 36 | Helpline calls, crisis events, safety plans |
| `sprint5_tests.py` | 45 | Care plans, assignment queue, referrals, comments |
| `sprint6_tests.py` | 46 | Treatment plans, prescriptions, dispensing |
| `sprint7_tests.py` | 62 | Follow-ups, LTFU, closure, supervision |
| `sprint8_tests.py` | 56 | Notifications, attachments, sync, audit logs |
| `sprint9_tests.py` | 54 | Lookups, workflow config, reports |
| **Total** | **408** | |

Each script prints `N passed, 0 failed` and exits non-zero on failure.
Sprints 0–2 are covered by build + seed verification (auth skeleton, policy
provider, patient identity).

---

## 6. Solution layout

```
AKA.CMS.sln
├── AKA.CMS.Domain/          Entities (POCOs), zero dependencies
├── AKA.CMS.Application/     DTOs, service + repository interfaces,
│                            services, FluentValidation validators
├── AKA.CMS.Infrastructure/  Dapper repositories (one stored-proc call
│                            per method), DapperContext, JWT + BCrypt
├── AKA.CMS.API/             Controllers, policy-based auth, middleware,
│                            Program.cs
├── database/
│   ├── 01_Schema/               CMS_* tables + seed (ordered scripts)
│   └── 02_StoredProcedures/     one file per module (ordered scripts)
├── test-scripts/                Python regression suite (per sprint)
├── docs/
│   ├── API_INVENTORY.md         auto-generated endpoint inventory
│   ├── gen_inventory.py         regenerates the inventory
│   └── aka-cms.postman_collection.json   happy-path Postman collection
├── SPRINTS_STATUS.md            per-sprint delivery log + open items
└── uploads/                     file-attachment storage (runtime)
```

**Non-negotiable rules (enforced every sprint):**

1. No inline SQL in C# — every repository method calls exactly one stored
   procedure (`CommandType.StoredProcedure`).
2. Every write proc uses `BEGIN TRAN / COMMIT / ROLLBACK` with `TRY/CATCH`.
3. Every write proc that touches `Cases` also writes an `AuditLogs` row in the
   same transaction.
4. Case status changes go **only** through `sp_WorkflowTransition_Apply`.
5. Mutating case endpoints accept `RowVersion`; mismatch → HTTP 409.
6. Authorization is policy-based from the `RolePermissions` table — never
   hard-coded role checks.
7. DTOs are never the domain entities.

---

## 7. Implemented sprints (summary)

- **Sprint 0** — Auth: `POST /api/auth/login`, `POST /api/auth/refresh`,
  `POST /api/auth/logout`; JWT bearer, refresh rotation, ProblemDetails middleware.
- **Sprint 1** — Users & roles: `GET/POST /api/users`, `GET/PUT /api/users/{id}`,
  `POST/DELETE /api/users/{id}/roles`, `GET/POST /api/roles`, `GET /api/roles/{id}`,
  `GET /api/roles/{id}/permissions`, `POST/DELETE /api/roles/{id}/permissions`,
  `GET /api/permissions` — all permission-gated.
- **Sprint 2** — Patient identity: `GET /api/patients/search`,
  `POST /api/patients/resolve-identity` (known MR → map, unknown MR →
  facility-scoped dummy `TMP-######`), `POST /api/patients/remap-mr`
  (dummy → real MR, RowVersion → 409), `POST /api/patients/members`,
  `GET/PUT /api/patients/mr-blocks`.
  Tables: `CMS_CommunityMembers`, `CMS_HisMrMappings`, `CMS_FacilityMrBlocks`;
  dummy MR blocks are seeded as placeholders until the client confirms real ranges.
- **Sprint 3** — Workflow engine: `POST /api/cases` (201, starts at INTAKE),
  `GET /api/cases/{id}`, `PUT /api/cases/{id}` (details only, stale RowVersion
  → 409), `POST /api/cases/{id}/transitions` (the only path that changes status:
  invalid action → 400, missing permission → 403, stale RowVersion → 409),
  `GET .../allowed-transitions` (with `canPerform` from JWT claims),
  `GET .../history`. Tables: `CMS_WorkflowStates` (13 states),
  `CMS_WorkflowTransitions` (22 transitions), `CMS_Cases`, `CMS_CaseHistories`;
  case numbers `CMS-YYYY-######`. Tests: 42.
- **Sprint 3b** — Awareness: `POST/GET /api/awareness-sessions`,
  `POST /api/awareness-sessions/{id}/participants`,
  `POST /api/cases/{id}/source`. Tests: 36.
- **Sprint 4** — Screening: `GET /api/screenings/tools`,
  `POST /api/screenings/submit` (item scores only — score/risk computed
  server-side), `GET /api/screenings/case/{caseId}`. Scores sync into the
  existing `MR_MENTALHEALTH` latest visit row; severe risk auto-escalates when
  allowed. PHQ-9 bands 0-4/5-9/10-14/15-19/20-27; GAD-7 bands 0-4/5-9/10-14/15-21.
  Tests: 31.
- **Sprint 4b** — Helpline & crisis: `POST /api/helpline/calls` (crisis
  indicators auto-create `CrisisEvent` + supervisor alert),
  `GET /api/crisis-events/types`, safety plans `POST/GET /api/safety-plans`.
  Tests: 36.
- **Sprint 5** — Care management: `GET /api/care-plans/routing-rules`,
  `POST /api/care-plans`, `POST /api/assignment-queue/route`,
  `POST /api/assignment-queue/{queueId}/assign` (204),
  `GET /api/assignment-queue/pending`, `POST /api/referrals`
  (`REF-YYYY-######`), `PATCH /api/referrals/{id}/status`
  (reject creates a NEW linked row), `POST/GET /api/case-comments`. Tests: 45.
- **Sprint 6** — Treatment: `POST /api/treatment-plans` (separate PSYCH/PHARM
  tracks; duplicate track → 409), `POST /api/psychological-sessions`,
  `POST /api/medications/prescriptions` (dictionary-limited, sequential Rx
  numbers), `POST .../dispense`, `PATCH .../cancel` (soft-cancel only),
  `GET /api/medications/dictionary`. Tests: 46.
- **Sprint 7** — Follow-up & closure: `POST /api/follow-ups/schedule`,
  `POST /api/follow-ups/{id}/outcome`, `GET /api/follow-ups/due`,
  `POST /api/ltfu/cases/{caseId}/evaluate`, `POST .../re-engage`,
  `POST /api/case-closures/request`, `POST /api/case-closures/{id}/approve`
  (supervisor-gated), `POST/GET /api/supervision/logs`. Tests: 62.
- **Sprint 8** — Notifications (`GET /api/notifications` paginated,
  `PATCH .../read`), attachments (`POST /api/case-attachments` multipart,
  `GET .../download`), sync (`POST /api/sync/push` idempotent,
  `GET /api/sync/pull`, `POST /api/sync/ack`, server-wins conflicts),
  audit (`GET /api/audit-logs` paginated). Tests: 56.
- **Sprint 9** — Master data & reporting: `GET /api/lookups/{type}` (9 seeded
  types), `GET /api/workflow/states`, admin workflow-transition CRUD,
  `GET /api/reports/case-summary|screening-summary|helpline-summary|followup-compliance|workload`.
  Tests: 54.
- **Sprint 10** — Hardening & handoff: rate limiting, security headers,
  correlation IDs, `/api/health`, full Swagger annotations, canonical
  pagination envelope, this handoff package.

See **`SPRINTS_STATUS.md`** for the per-sprint delivery log, test counts, and
the consolidated list of open client-confirmation items.

---

## 8. Handoff documents

| Document | Purpose |
|---|---|
| `docs/API_INVENTORY.md` | Every endpoint: method, route, auth policy, responses (regenerate via `python3 docs/gen_inventory.py`) |
| `docs/aka-cms.postman_collection.json` | Postman collection — 46 happy-path requests, 11 folders; import and set `baseUrl`, then run 01 Auth first |
| `SPRINTS_STATUS.md` | Sprint-by-sprint delivery log + open items for the client |
| Swagger UI (`/swagger`, dev) | Interactive contract for the Flutter developer |
