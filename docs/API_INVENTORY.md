# AKA-CMS API Inventory

Auto-generated from `AKA.CMS.API/Controllers/` by `docs/gen_inventory.py`.
Do not edit by hand — re-run the script after controller changes.

- Generated: 2026-09-17
- Controllers: 31
- Endpoints: 103
- Auth: every endpoint except `POST /api/auth/login`, `POST /api/auth/refresh`
  and `GET /api/health` requires a JWT Bearer token; the `Auth` column names
  the permission policy (resolved from the `RolePermissions` table at startup).
- Error payloads are RFC 7807 `application/problem+json`.

### AssignmentQueueController — `api/assignment-queue`
*Manages the case-assignment queue (routing and assignment).*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| POST | `/api/assignment-queue/route` | PermissionPolicies.AssignmentQueueWrite | Status200OK, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Route. |
| POST | `/api/assignment-queue/{queueId:int}/assign` | PermissionPolicies.AssignmentQueueWrite | Status204NoContent, Status400BadRequest, Status401Unauthorized, Status403Forbidden, Status409Conflict | Assign. |
| GET | `/api/assignment-queue/pending` | PermissionPolicies.AssignmentQueueRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get pending. |

### AuditLogsController — `api/audit-logs`
*Queries the audit trail (read-only).*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/audit-logs` | PermissionPolicies.AuditLogsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Query. |

### AuthController — `api/auth`
*Authentication: login, token refresh, logout.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| POST | `/api/auth/login` | anonymous | Status401Unauthorized, Status400BadRequest, Status200OK | Authenticates a user and returns access + refresh tokens. |
| POST | `/api/auth/refresh` | anonymous | Status401Unauthorized, Status400BadRequest, Status200OK | Exchanges a valid refresh token for a new token pair. |
| POST | `/api/auth/logout` | authenticated | Status401Unauthorized, Status400BadRequest, Status204NoContent | Revokes a refresh token (logout). |

### AwarenessSessionsController — `api/awareness-sessions`
*Manages community awareness sessions and participants.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| POST | `/api/awareness-sessions` | PermissionPolicies.AwarenessSessionsWrite | Status201Created, Status401Unauthorized, Status403Forbidden | Create. |
| GET | `/api/awareness-sessions` | PermissionPolicies.AwarenessSessionsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get list. |
| GET | `/api/awareness-sessions/{id:int}` | PermissionPolicies.AwarenessSessionsRead | Status200OK, Status401Unauthorized, Status403Forbidden, Status404NotFound | Get by id. |
| PATCH | `/api/awareness-sessions/{id:int}` | PermissionPolicies.AwarenessSessionsWrite | Status200OK, Status401Unauthorized, Status403Forbidden | Update. |
| POST | `/api/awareness-sessions/{id:int}/participants` | PermissionPolicies.AwarenessSessionsWrite | Status201Created, Status401Unauthorized, Status403Forbidden | Register participant. |

### CarePlansController — `api/care-plans`
*Manages action care plans and risk-routing rules.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/care-plans/routing-rules` | PermissionPolicies.CarePlansRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get routing rules. |
| POST | `/api/care-plans` | PermissionPolicies.CarePlansWrite | Status201Created, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Create. |
| GET | `/api/care-plans/case/{caseId:int}` | PermissionPolicies.CarePlansRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get by case. |

### CaseAttachmentsController — `(action-level routes)`
*Uploads and lists case file attachments.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| POST | `/api/case-attachments` | PermissionPolicies.AttachmentsWrite | Status201Created, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Upload. |
| GET | `/api/cases/{caseId:int}/attachments` | PermissionPolicies.AttachmentsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get by case. |
| GET | `/api/case-attachments/{id:int}/download` | PermissionPolicies.AttachmentsRead | Status200OK, Status401Unauthorized, Status403Forbidden, Status404NotFound | Download. |

### CaseClosureController — `api/case-closures`
*Handles case-closure requests and supervisor approval.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/case-closures/by-case` | PermissionPolicies.CaseClosureRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get by case. |
| POST | `/api/case-closures/request` | PermissionPolicies.CaseClosureWrite | Status200OK, Status401Unauthorized, Status403Forbidden | Request closure. |
| POST | `/api/case-closures/{id:int}/approve` | PermissionPolicies.CaseClosureApprove | Status200OK, Status401Unauthorized, Status403Forbidden | Approve. |

### CaseCommentsController — `api/case-comments`
*Manages notes/comments on cases.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| POST | `/api/case-comments` | PermissionPolicies.CaseCommentsWrite | Status201Created, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Add. |
| GET | `/api/case-comments/case/{caseId:int}` | PermissionPolicies.CaseCommentsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get by case. |

### CaseSourceController — `api/cases/{id:int}/source`
*Records and retrieves case-source mappings.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| POST | `/api/cases/{id:int}/source` | PermissionPolicies.CaseSourcesWrite | Status201Created, Status401Unauthorized, Status403Forbidden | Record. |
| GET | `/api/cases/{id:int}/source` | PermissionPolicies.CaseSourcesRead | Status200OK, Status401Unauthorized, Status403Forbidden, Status404NotFound | Get by case. |

### CasesController — `api/cases`
*Registers cases, manages details, applies workflow transitions.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| POST | `/api/cases` | PermissionPolicies.CasesWrite | Status201Created, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Create. |
| GET | `/api/cases/{id:int}` | PermissionPolicies.CasesRead | Status200OK, Status401Unauthorized, Status403Forbidden, Status404NotFound | Get by id. |
| PUT | `/api/cases/{id:int}` | PermissionPolicies.CasesWrite | Status200OK, Status400BadRequest, Status401Unauthorized, Status403Forbidden, Status404NotFound, Status409Conflict | Update details. |
| POST | `/api/cases/{id:int}/transitions` | PermissionPolicies.CasesWrite | Status200OK, Status400BadRequest, Status401Unauthorized, Status403Forbidden, Status409Conflict | Apply transition. |
| POST | `/api/cases/{id:int}/assign` | PermissionPolicies.CasesWrite | Status204NoContent, Status400BadRequest, Status401Unauthorized, Status403Forbidden, Status409Conflict | Assign. |
| GET | `/api/cases/{id:int}/allowed-transitions` | PermissionPolicies.CasesRead | Status200OK, Status401Unauthorized, Status403Forbidden, Status404NotFound | Get allowed transitions. |
| GET | `/api/cases/{id:int}/history` | PermissionPolicies.CasesRead | Status200OK, Status401Unauthorized, Status403Forbidden, Status404NotFound | Get history. |

### CrisisEventsController — `api/crisis-events`
*Manages crisis events and crisis types.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/crisis-events/types` | PermissionPolicies.CrisisRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get types. |
| POST | `/api/crisis-events` | PermissionPolicies.CrisisWrite | Status201Created, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Trigger. |
| PATCH | `/api/crisis-events/{id:int}/status` | PermissionPolicies.CrisisWrite | Status200OK, Status401Unauthorized, Status403Forbidden | Update status. |
| GET | `/api/crisis-events/case/{caseId:int}` | PermissionPolicies.CrisisRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get by case. |

### FollowUpsController — `api/follow-ups`
*Schedules follow-ups and records their outcomes.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/follow-ups/by-case` | PermissionPolicies.FollowUpsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get by case. |
| GET | `/api/follow-ups/due` | PermissionPolicies.FollowUpsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get due. |
| POST | `/api/follow-ups/schedule` | PermissionPolicies.FollowUpsWrite | Status200OK, Status401Unauthorized, Status403Forbidden | Schedule. |
| POST | `/api/follow-ups/{id:int}/outcome` | PermissionPolicies.FollowUpsWrite | Status200OK, Status401Unauthorized, Status403Forbidden | Record outcome. |

### HealthController — `api/health`
*Liveness probe for load balancers / uptime monitors. Anonymous on purpose.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/health` | anonymous | Status503ServiceUnavailable, Status200OK | Returns 200 when the API and its database are reachable, 503 otherwise. |

### HelplineController — `api/helpline`
*Logs helpline calls (with automatic crisis detection).*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| POST | `/api/helpline/calls` | PermissionPolicies.HelplineWrite | Status201Created, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Log call. |
| GET | `/api/helpline/calls` | PermissionPolicies.HelplineRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get calls. |

### LookupsController — `api/lookups`
*Generic master-data lookup endpoint.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/lookups/{type}` | PermissionPolicies.LookupsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get by type. |

### LtfuController — `api/ltfu`
*Lost-to-follow-up detection and re-engagement.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/ltfu/by-case` | PermissionPolicies.FollowUpsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get by case. |
| POST | `/api/ltfu/cases/{caseId:int}/evaluate` | PermissionPolicies.FollowUpsWrite | Status200OK, Status401Unauthorized, Status403Forbidden | Evaluate. |
| POST | `/api/ltfu/cases/{caseId:int}/re-engage` | PermissionPolicies.FollowUpsWrite | Status200OK, Status401Unauthorized, Status403Forbidden | Re engage. |

### MedicationsController — `api/medications`
*Manages prescriptions, dispensing and the formulary.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/medications/dictionary` | PermissionPolicies.MedicationsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get dictionary. |
| GET | `/api/medications/prescriptions` | PermissionPolicies.MedicationsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get prescriptions. |
| POST | `/api/medications/prescriptions` | PermissionPolicies.MedicationsWrite | Status200OK, Status401Unauthorized, Status403Forbidden | Create prescription. |
| PATCH | `/api/medications/prescriptions/{id:int}/cancel` | PermissionPolicies.MedicationsWrite | Status204NoContent, Status401Unauthorized, Status403Forbidden | Cancel prescription. |
| POST | `/api/medications/prescriptions/{id:int}/dispense` | PermissionPolicies.MedicationsWrite | Status200OK, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Dispense. |

### NotificationsController — `api/notifications`
*Sends and reads user notifications.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/notifications` | PermissionPolicies.NotificationsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get by user. |
| POST | `/api/notifications` | PermissionPolicies.NotificationsWrite | Status201Created, Status401Unauthorized, Status403Forbidden | Send. |
| PATCH | `/api/notifications/{id:int}/read` | PermissionPolicies.NotificationsWrite | Status204NoContent, Status401Unauthorized, Status403Forbidden, Status404NotFound | Mark as read. |
| POST | `/api/notifications/read-all` | PermissionPolicies.NotificationsWrite | Status200OK, Status401Unauthorized, Status403Forbidden | Mark all read. |

### PatientsController — `api/patients`
*Patient identity: search and MR resolution.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/patients/search` | PermissionPolicies.PatientsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Search. |
| POST | `/api/patients/resolve-identity` | PermissionPolicies.PatientsWrite | Status201Created, Status401Unauthorized, Status403Forbidden | Resolve identity. |
| POST | `/api/patients/remap-mr` | PermissionPolicies.PatientsWrite | Status200OK, Status400BadRequest, Status401Unauthorized, Status403Forbidden, Status409Conflict | Remap mr. |
| POST | `/api/patients/members` | PermissionPolicies.PatientsWrite | Status201Created, Status401Unauthorized, Status403Forbidden | Register member. |
| GET | `/api/patients/mr-blocks` | PermissionPolicies.PatientsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get mr blocks. |
| PUT | `/api/patients/mr-blocks` | PermissionPolicies.PatientsWrite | Status204NoContent, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Upsert mr block. |

### PermissionsController — `api/permissions`
*Reads the permission catalog.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/permissions` | PermissionPolicies.PermissionsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get catalog. |

### PsychologicalSessionsController — `api/psychological-sessions`
*Logs psychological-therapy sessions.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| POST | `/api/psychological-sessions` | PermissionPolicies.PsychologicalSessionsWrite | Status200OK, Status401Unauthorized, Status403Forbidden | Record. |
| GET | `/api/psychological-sessions` | PermissionPolicies.PsychologicalSessionsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get by case. |

### ReferralsController — `api/referrals`
*Creates referrals and tracks accept/reject.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| POST | `/api/referrals` | PermissionPolicies.ReferralsWrite | Status201Created, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Create. |
| PATCH | `/api/referrals/{referralId:int}/status` | PermissionPolicies.ReferralsWrite | Status200OK, Status401Unauthorized, Status403Forbidden | Update status. |
| GET | `/api/referrals/case/{caseId:int}` | PermissionPolicies.ReferralsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get by case. |

### ReportsController — `api/reports`
*Aggregate reports and dashboard figures.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/reports/case-summary` | PermissionPolicies.ReportsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get case summary. |
| GET | `/api/reports/screening-summary` | PermissionPolicies.ReportsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get screening summary. |
| GET | `/api/reports/helpline-summary` | PermissionPolicies.ReportsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get helpline summary. |
| GET | `/api/reports/followup-compliance` | PermissionPolicies.ReportsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get follow up compliance. |
| GET | `/api/reports/workload` | PermissionPolicies.ReportsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get workload. |

### RolesController — `api/roles`
*Manages roles and their permission assignments.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/roles` | PermissionPolicies.RolesRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get all. |
| GET | `/api/roles/{id:int}` | PermissionPolicies.RolesRead | Status200OK, Status401Unauthorized, Status403Forbidden, Status404NotFound | Get by id. |
| POST | `/api/roles` | PermissionPolicies.RolesWrite | Status201Created, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Create. |
| GET | `/api/roles/{id:int}/permissions` | PermissionPolicies.RolesRead | Status200OK, Status401Unauthorized, Status403Forbidden, Status404NotFound | Get permissions. |
| POST | `/api/roles/{id:int}/permissions` | PermissionPolicies.RolesWrite | Status204NoContent, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Assign permission. |
| DELETE | `/api/roles/{id:int}/permissions/{controllerActionId:int}` | PermissionPolicies.RolesWrite | Status204NoContent, Status401Unauthorized, Status403Forbidden, Status404NotFound | Remove permission. |

### SafetyPlansController — `api/safety-plans`
*Creates and reads safety plans for crisis cases.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| POST | `/api/safety-plans` | PermissionPolicies.SafetyPlansWrite | Status201Created, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Create. |
| GET | `/api/safety-plans/case/{caseId:int}` | PermissionPolicies.SafetyPlansRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get by case. |

### ScreeningsController — `api/screenings`
*Records PHQ-9 / GAD-7 screenings with risk stratification.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/screenings/tools` | PermissionPolicies.ScreeningsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get tools. |
| POST | `/api/screenings/submit` | PermissionPolicies.ScreeningsWrite | Status201Created, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Submit. |
| GET | `/api/screenings/case/{caseId:int}` | PermissionPolicies.ScreeningsRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get by case. |

### SupervisionController — `api/supervision`
*Logs clinical supervision sessions.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/supervision/logs/by-case` | PermissionPolicies.SupervisionRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get by case. |
| POST | `/api/supervision/logs` | PermissionPolicies.SupervisionWrite | Status200OK, Status401Unauthorized, Status403Forbidden | Log review. |

### SyncController — `api/sync`

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| POST | `/api/sync/push` | PermissionPolicies.SyncWrite | Status200OK, Status400BadRequest, Status401Unauthorized, Status403Forbidden, Status409Conflict | Pushes one offline change; duplicates return 409 with the existing record. |
| GET | `/api/sync/pull` | PermissionPolicies.SyncRead | Status200OK, Status401Unauthorized, Status403Forbidden | Pulls server-side changes since a watermark, paginated. |
| POST | `/api/sync/ack` | PermissionPolicies.SyncWrite | Status200OK, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Acknowledges receipt of a pushed change. |

### TreatmentPlansController — `api/treatment-plans`
*Manages psychological and pharmacological treatment plans.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| POST | `/api/treatment-plans` | PermissionPolicies.TreatmentPlansWrite | Status201Created, Status401Unauthorized, Status403Forbidden | Create. |
| GET | `/api/treatment-plans` | PermissionPolicies.TreatmentPlansRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get list. |
| GET | `/api/treatment-plans/{id:int}` | PermissionPolicies.TreatmentPlansRead | Status200OK, Status401Unauthorized, Status403Forbidden, Status404NotFound | Get by id. |
| PATCH | `/api/treatment-plans/{id:int}` | PermissionPolicies.TreatmentPlansWrite | Status200OK, Status401Unauthorized, Status403Forbidden | Update. |

### UsersController — `api/users`
*Manages users and their role assignments.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/users` | PermissionPolicies.UsersRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get all. |
| GET | `/api/users/{id:int}` | PermissionPolicies.UsersRead | Status200OK, Status401Unauthorized, Status403Forbidden, Status404NotFound | Get by id. |
| POST | `/api/users` | PermissionPolicies.UsersWrite | Status201Created, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Create. |
| PUT | `/api/users/{id:int}` | PermissionPolicies.UsersWrite | Status200OK, Status400BadRequest, Status401Unauthorized, Status403Forbidden, Status404NotFound | Update. |
| POST | `/api/users/{id:int}/roles` | PermissionPolicies.UsersWrite | Status204NoContent, Status400BadRequest, Status401Unauthorized, Status403Forbidden | Assign role. |
| DELETE | `/api/users/{id:int}/roles/{roleId:int}` | PermissionPolicies.UsersWrite | Status204NoContent, Status401Unauthorized, Status403Forbidden, Status404NotFound | Remove role. |

### WorkflowConfigController — `api/workflow`
*Admin configuration of workflow states and transitions.*

| Method | Route | Auth | Responses | Description |
|---|---|---|---|---|
| GET | `/api/workflow/states` | PermissionPolicies.WorkflowConfigRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get states. |
| GET | `/api/workflow/transitions` | PermissionPolicies.WorkflowConfigRead | Status200OK, Status401Unauthorized, Status403Forbidden | Get transitions. |
| POST | `/api/workflow/transitions` | PermissionPolicies.WorkflowConfigWrite | Status200OK, Status401Unauthorized, Status403Forbidden | Create transition. |
| PATCH | `/api/workflow/transitions/{id:int}` | PermissionPolicies.WorkflowConfigWrite | Status204NoContent, Status401Unauthorized, Status403Forbidden | Set transition active. |
