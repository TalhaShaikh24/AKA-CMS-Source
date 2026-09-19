# AKA-CMS — Sprint Status (Sprints 0–10)

**Date:** 2026-09-17 · **Solution:** `AKA.CMS.sln` (.NET 8, Clean Architecture)
**Regression:** 408/408 green · **Build:** 0 errors, 0 warnings

Test counts are assertions in `test-scripts/sprint*_tests.py` (Python + stdlib,
run against the live API). Sprints 0–2 predate the per-sprint suites and are
covered by build + seed verification.

---

## Sprint 0 — Foundation ✅
Auth skeleton: Clean Architecture 4-project layout, Dapper + stored procedures
only, `DapperContext`, JWT login (`POST /api/auth/login`) with refresh-token
rotation, global exception → RFC 7807 `ProblemDetails` middleware, Swagger with
JWT Bearer support, Serilog. **DoD:** login as seeded admin returns a valid JWT;
bad login → clean 401. *(Covered by build/seed verification.)*

## Sprint 1 — Users, Roles, Facilities ✅
`UsersController` (CRUD + role assignment), `RolesController` (read + permission
listing/assignment), `PermissionsController` (catalog). Dynamic policy-based
authorization from the `RolePermissions` table (`PermissionPolicyProvider` +
`PermissionCatalog` loaded at startup) — no hard-coded role checks.
*(Covered by build/seed verification.)*

## Sprint 2 — Patient Identity & MR Resolution ✅
`CMS_CommunityMembers`, `CMS_HisMrMappings`, `CMS_FacilityMrBlocks`;
`GET /api/patients/search`, `POST /api/patients/resolve-identity` (known MR →
map; unknown MR → dummy MR from the facility's reserved block),
`POST /api/patients/remap-mr` (dummy → real MR, RowVersion → 409),
`POST /api/patients/members`, `GET/PUT /api/patients/mr-blocks`.
**DoD:** unknown-MR resolve creates a facility-scoped dummy-MR record.
*(Covered by build/seed verification.)*

## Sprint 3 — Workflow Engine ✅ · 42 tests
13 states (`INTAKE`…`CLOSED`), 22 transitions; `CMS_Cases`, `CMS_CaseHistories`;
`POST /api/cases` (201, `CMS-YYYY-######`), `PUT /api/cases/{id}` (details only),
`POST /api/cases/{id}/transitions` — the **only** path that changes status
(invalid → 400, no permission → 403, stale RowVersion → 409),
`GET .../allowed-transitions` (with `canPerform`), `GET .../history`.
**DoD:** screening → risk score → auto-categorization → queued for assignment.

## Sprint 3b — Awareness Sessions ✅ · 36 tests
`AwarenessSessions`, `SessionParticipants`, `CaseSourceMapping`:
`POST/GET/PATCH /api/awareness-sessions`, `POST .../{id}/participants`,
`POST /api/cases/{id}/source`. Full regression 190/190 green at completion.

## Sprint 4 — Screening & Risk Stratification ✅ · 31 tests
`GET /api/screenings/tools`, `POST /api/screenings/submit` (item scores only;
server-side PHQ-9/GAD-7 scoring from `CMS_ScreeningRiskBands`),
`GET /api/screenings/case/{caseId}`. Scores sync into the existing
`MR_MENTALHEALTH` latest visit row (never invents clinical rows); severe risk
auto-escalates when the state machine allows it.

## Sprint 4b — Helpline & Crisis (Module 2) ✅ · 36 tests
`POST /api/helpline/calls` with automatic `CrisisEvent` creation on crisis
indicators (suicidal intent, self-harm, psychosis, panic attack, substance
crisis), supervisor alerts, emergency case routing, safety plans
(`POST/GET /api/safety-plans`), `GET /api/crisis-events/types`.

## Sprint 5 — Case Management, Assignment & Referral ✅ · 45 tests
Risk-routing rules + SLA queue, `POST /api/assignment-queue/route`,
`POST /api/assignment-queue/{queueId}/assign` (204, RowVersion-checked),
`POST /api/care-plans`, `POST /api/referrals` (`REF-YYYY-######`),
`PATCH /api/referrals/{id}/status` (reject keeps the old row, creates a NEW
linked row), `POST/GET /api/case-comments`.

## Sprint 6 — Psychological + Pharmacological Treatment ✅ · 46 tests
Separate PSYCH / PHARM treatment-plan tracks (duplicate track → 409),
psychological session logging, dictionary-limited prescriptions with sequential
Rx numbers, soft-cancel only, dispensing audit trail. Full regression 236/236
green at completion.

## Sprint 7 — Follow-Up / LTFU / Closure / Supervision ✅ · 62 tests
`POST /api/follow-ups/schedule`, `POST /api/follow-ups/{id}/outcome`,
`GET /api/follow-ups/due`, `POST /api/ltfu/cases/{caseId}/evaluate` +
`.../re-engage`, `POST /api/case-closures/request`,
`POST /api/case-closures/{id}/approve` (supervisor-gated),
`POST/GET /api/supervision/logs`.

## Sprint 8 — Notifications / Attachments / Sync ✅ · 56 tests
`GET /api/notifications` (paginated), `PATCH .../read`,
`POST /api/case-attachments` (multipart upload, `GET .../download`),
`POST /api/sync/push` (idempotent via client key; duplicate → 409),
`GET /api/sync/pull`, `POST /api/sync/ack` (server-wins conflicts),
`GET /api/audit-logs` (paginated).

## Sprint 9 — Master Data / Reporting ✅ · 54 tests
`GET /api/lookups/{type}` (9 seeded types), `GET /api/workflow/states`
(read-only), admin workflow-transition CRUD (201/204/404/409 with RowVersion),
`GET /api/reports/case-summary|screening-summary|helpline-summary|followup-compliance|workload`
(consistent with API-created data; date + unit filters; audit rows for
workflow-config writes).

## Sprint 10 — Hardening & Handoff ✅ (this sprint)
- **Global exception handling:** RFC 7807 `ProblemDetails` for all errors
  (400 validation, 401, 403, 404, 409 conflict/concurrency, 500) with
  `X-Correlation-Id` in payload and logs. Audit: no controller leaks raw
  exceptions (no try/catch in controllers; all errors flow through the middleware).
- **Rate limiting:** ASP.NET Core fixed-window limiter on auth endpoints
  (login/refresh/logout) — 60 req/min/IP, HTTP 429 on exceed. Value is
  provisional (documented in `Program.cs`).
- **Security headers:** `X-Content-Type-Options: nosniff`,
  `X-Frame-Options: DENY`, `Referrer-Policy`, `Permissions-Policy`, HSTS outside
  Development (`SecurityHeadersMiddleware`).
- **`GET /api/health`:** 200 with DB connectivity check via new
  `sp_CMS_Health_Check`; 503 when the DB is unreachable. Anonymous.
- **Correlation ID:** `X-Correlation-Id` generated/propagated per request
  (`CorrelationIdMiddleware`), included in Serilog log context.
- **Swagger:** XML doc generation + `IncludeXmlComments`; every controller has
  class/method summaries and `[ProducesResponseType]` on all 103 endpoints —
  the contract document for the Flutter developer.
- **Pagination:** canonical `PagedResult<T>` envelope
  (`items`, `totalCount`, `page`, `pageSize`); `AuditLogQueryResponse`,
  `NotificationListResponse`, `SyncPullResponse` now derive from it (JSON shape
  unchanged). Non-paginated list endpoints return plain arrays by design.
- **Dev-only endpoints:** none exist — no seed/debug controllers in the API
  (seeding is SQL-script only). Swagger remains Development-gated.
- **FluentValidation:** 48/48 write/query DTOs covered — added the 3 missing
  validators (`RefreshTokenRequest`, `SyncAckRequest`, `AuditLogQueryRequest`);
  `IAuthService.Refresh/Logout` now take the request DTO and validate at the
  service layer like everything else.
- **No-raw-SQL check:** `grep` over the four project folders — zero inline SQL. The single match
  is a string constant of allowed sync actions (`"CREATE","UPDATE","DELETE"`),
  not SQL.
- **Handoff package:** `README.md` (full setup), `docs/API_INVENTORY.md`
  (+ `docs/gen_inventory.py` generator), `docs/aka-cms.postman_collection.json`
  (46 requests, 11 folders), this file.

---

## Regression totals

| Suite | Passed | Failed |
|---|---|---|
| sprint3 | 42 | 0 |
| sprint3b_awareness | 36 | 0 |
| sprint4 | 31 | 0 |
| sprint4b_helpline | 36 | 0 |
| sprint5 | 45 | 0 |
| sprint6 | 46 | 0 |
| sprint7 | 62 | 0 |
| sprint8 | 56 | 0 |
| sprint9 | 54 | 0 |
| **Total** | **408** | **0** |

Run: start the API on `http://localhost:5000`, then
`for t in test-scripts/sprint*_tests.py; do python3 "$t"; done`.

---

## Open client-confirmation items (consolidated)

These were deliberately **not** blocked on — sensible provisionals are in place:

1. **Facility MR block ranges** — seeded as placeholders (`TMP-######`,
   `IsPlaceholder = 1`); real ranges pending.
2. **`Other Acute Crisis` catch-all crisis type** — exists; clinical sign-off pending.
3. **Anonymous (caseless) crisis handling** — current behavior to confirm.
4. **`WalkIn` / `Referral` case-source codes** — seeded; confirm against client list.
5. **7 therapy modalities + 9 formulary medicines** — provisional seed; clinical
   confirmation pending.
6. **LTFU threshold (1 missed visit) + follow-up frequencies (7/14/30 days)** —
   provisional; confirm.
7. **Sync conflict strategy = server-wins** — design decision to confirm.
8. **Attachment limits: 10 MB, provisional file types** — confirm.
9. **No `CMS_Facilities` master** — HIS `UNIT` is the facility registry
   (design decision to confirm).
10. **Rate-limit values** (60 req/min/IP on auth endpoints) — provisional;
    tighten with per-account limits + alerting before production.
11. **`ScreeningTools` seed uses `SRQ`/`KMSS`** instead of the document's exact
    `SBQ-R`/`C-SSRS` — carried over from the original handoff doc.
12. **HIS sync interval** (`SystemSettings.Sync.ScheduleIntervalMinutes = 60`) —
    placeholder.
13. **Real SMS/Email/Push provider** — stub/interface only until credentials are
    confirmed (commercial item).
14. **Financials table mismatch in `Info_required.docx`** — commercial, not technical.

Deferred (explicitly out of scope): Flutter app itself, lab-server integration,
VAPT remediation (after KPMG assessment), AI/ML, legacy data migration, DR/BCP,
app-store publishing.
