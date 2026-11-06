# Leave App

Employee leave management application for WSO2. Supports location-specific leave types for Sri Lanka, France, and Spain.

## Architecture

- **Backend**: Ballerina (port 9090)
- **Frontend**: React 19 + Vite + MUI 7 + Redux Toolkit (port 3000)
- **Database**: MySQL
- **Auth**: WSO2 Asgardeo (SPA OAuth2 + JWT)
- **HR Data**: Fetched from HR Entity GraphQL service (separate repo: `digiops-hr/entity`)

## Local Development Setup

### Prerequisites

- Ballerina 2201.9.x
- Node.js 18+
- MySQL 8+

### Database

```sql
CREATE DATABASE leave_app;
CREATE USER 'leave_app_user'@'localhost' IDENTIFIED BY 'leave_app_pass';
GRANT ALL PRIVILEGES ON leave_app.* TO 'leave_app_user'@'localhost';
FLUSH PRIVILEGES;
```

### Backend

1. Create `backend/Config.toml` (not committed — contains secrets):

```toml
# --- Root-level configurables ---
[leave_service]
emailGroupToNotify = "leave-management@company.com"
sabbaticalFunctionalLeadOptOutMails = ["peter@company.com"]
sabbaticalMailGroups = ["sabbatical-management@company.com"]
isSabbaticalLeaveEnabled = true
sabbaticalLeaveApprovalUrl = "https://localhost:3000/approve/sabbatical"
sabbaticalLeavePolicyUrl = "<policy-doc-url>"
sabbaticalLeaveUserGuideUrl = "<user-guide-url>"
# Optional (defaults shown)
sabbaticalLeaveEligibilityDuration = 2555 # days (7 years)
sabbaticalLeaveMaxApplicationDuration = 42 # days (6 weeks)
sabbaticalLeaveMinJobBand = 5

# --- Email Module ---
[leave_service.email]
emailServiceBaseUrl = "<email-service-url>"
isDebug = true
emailNotificationsEnabled = false
debugRecipients = ["<your-email>"]
additionalCommentTemplate = "leaveAdditionalComment"

[leave_service.email.emailServiceConfig]
baseUrl = "<email-service-url>"
emailFrom = "Leave App <noreply@company.com>"

[leave_service.email.choreoAppConfig]
tokenUrl = "https://api.asgardeo.io/t/wso2/oauth2/token"
clientId = "<client-id>"
clientSecret = "<client-secret>"

# --- Employee Module ---
[leave_service.employee]
hrEntityBaseUrl = "<hr-entity-graphql-url>"

[leave_service.employee.oauthConfig]
tokenUrl = "https://api.asgardeo.io/t/wso2/oauth2/token"
clientId = "<client-id>"
clientSecret = "<client-secret>"

[leave_service.employee.retryConfig]
count = 3
interval = 3.0
backOffFactor = 2.0
maxWaitInterval = 20.0

# --- Calendar Events Module ---
[leave_service.calendar_events]
eventBaseUrl = "<calendar-event-service-url>"

[leave_service.calendar_events.choreoAppConfig]
tokenUrl = "https://api.asgardeo.io/t/wso2/oauth2/token"
clientId = "<client-id>"
clientSecret = "<client-secret>"

# --- Database Module ---
[leave_service.database.databaseConfig]
user = "leave_app_user"
password = "leave_app_pass"
database = "leave_app"
host = "localhost"
port = 3306

[leave_service.database.databaseConfig.connectionPool]
maxOpenConnections = 10
maxConnectionLifeTime = 100.0
minIdleConnections = 3

# --- Authorization Roles ---
[leave_service.authorization.authorizedRoles]
employeeRoles = ["employee-role"]
internRoles = ["intern-role"]
peopleOpsTeamRoles = ["hr-team-role"]
# Optional. Each grants one org-wide report on its own; an empty or missing list grants nobody.
generalReportRoles = ["general-leave-report-role"]
sabbaticalReportRoles = ["sabbatical-report-role"]
# Required. Members can download any sick note and list them (see Sick Notes).
sickNoteRoles = ["sick-note-role"]
```

The backend also needs these root-level settings (required: the service does not start without them), under
`[leave_service]`:

```toml
# Base64 of exactly 32 random bytes (e.g. `openssl rand -base64 32`). Keep it in the secret store, one per environment.
sickNoteEncryptionKey = "<base64-32-byte-key>"
# Page where the lead approves or rejects Other Authorized Leave
otherAuthorizedApprovalUrl = "https://localhost:3000/approve/other-authorized"
```

2. Build and run:

```bash
cd backend
bal build
bal run
```

Backend runs on `http://localhost:9090`.

### Frontend

1. Configure `webapp/public/config.js`:

```js
window.config = {
  APP_NAME: "WSO2 Leave App",
  APP_DOMAIN: "localhost",
  ASGARDEO_BASE_URL: "https://api.asgardeo.io/t/wso2",
  ASGARDEO_CLIENT_ID: "<asgardeo-spa-client-id>",
  ASGARDEO_REVOKE_ENDPOINT: "https://api.asgardeo.io/t/wso2/oauth2/revoke",
  AUTH_SIGN_IN_REDIRECT_URL: "http://localhost:3000",
  AUTH_SIGN_OUT_REDIRECT_URL: "http://localhost:3000",
  REACT_APP_BACKEND_BASE_URL: "http://localhost:9090",
};
```

2. Install and run:

```bash
cd webapp
npm install
npm run dev
```

Frontend runs on `http://localhost:3000`.

### Leave Scheduler

`leave-scheduler/` is a separate Ballerina program, deployed as a Choreo Scheduled Task that runs once a day. Each
run executes every job in turn; a failing job does not stop the others, and the run is reported as failed if any job
failed.

#### Sabbatical Reminder Job

Each run emails the lead of every approved sabbatical leave starting within the next 28 days
(`sabbaticalReminderLeadTimeInDays`) that has not had its reminder yet (To: the employee's current lead in the HR
entity service, or the approving lead when HR has none; CC: People Operations and the employee), then records the
send in `leave_submissions.sabbatical_reminder_sent_on`. A leave approved less than 4 weeks before it starts gets its
reminder on the next run; a failed send is retried on the next run.

#### Approval Reminder Job

Reminds the applicant's current lead (from the HR entity service) about Other Authorized Leave that is still pending.
The first reminder goes out once the request has waited `approvalReminderFirstDelayInDays`, then again every
`approvalReminderIntervalInDays`; each reminder is recorded so it is not repeated early, and a failed send is retried
on the next run. When HR has no lead for the applicant, or no longer has the applicant (for example after they left),
People Operations is alerted instead, on the same schedule. The email links to `approvalPageUrl`.

| Config | Description |
|--------|-------------|
| `approvalReminderFirstDelayInDays` | Days a request waits before the first reminder (required, at least 1) |
| `approvalReminderIntervalInDays` | Days between later reminders (required, at least 1) |
| `approvalPageUrl` | Approval page linked in the email (required, not empty) |

#### Sick Note Retention Job

Clears the stored content of sick notes whose leave ended more than `sickNoteRetentionInDays` days ago, and of notes
on cancelled leaves. The `leave_attachments` row is kept, so the history can still show that a note was provided and
later deleted. The job does not need the encryption key, and debug mode does not skip the deletion.

| Config | Description |
|--------|-------------|
| `sickNoteRetentionInDays` | Days after the leave ends before the note is cleared (required, at least 1) |

#### Running the Scheduler

1. Apply `backend/resources/leave_app_update_v1.1.1.sql` and `backend/resources/leave_app_update_v1.2.0.sql` to the
   leave database (reminder column; France leave types, approvals and sick notes), and give the scheduler's database
   user the [grants below](#scheduler-database-access).
2. Copy `leave-scheduler/Config.toml.local` to `leave-scheduler/Config.toml` and fill it in. In non-production
   environments keep `isDebug = true` with your address in `debugRecipients`: reminders then go only there, with no
   CC, and are not marked as sent. Set every required setting (`approvalReminderFirstDelayInDays`,
   `approvalReminderIntervalInDays`, `approvalPageUrl`, `sickNoteRetentionInDays`): a missing one stops the scheduler
   at startup, and a value of 0 makes the matching job fail on purpose.
3. Build and run:

```bash
cd leave-scheduler
bal build
bal run
```

#### Scheduler Database Access

| Job | Reads | Writes |
|-----|-------|--------|
| Sabbatical reminder | `leave_submissions` | `leave_submissions.sabbatical_reminder_sent_on` |
| Approval reminder | `leave_submissions` | `leave_submissions.approval_reminder_sent_on` |
| Sick note retention | `leave_attachments`, and `leave_submissions` to find ended and cancelled leaves | `leave_attachments.content`, `iv` and `deleted_at` |

The retention job's `UPDATE … JOIN` also reads both tables, so the scheduler's database user needs at least:

```sql
GRANT SELECT ON <leave_db>.leave_submissions TO '<scheduler_user>'@'<host>';
GRANT UPDATE (sabbatical_reminder_sent_on, approval_reminder_sent_on)
  ON <leave_db>.leave_submissions TO '<scheduler_user>'@'<host>';
GRANT SELECT, UPDATE ON <leave_db>.leave_attachments TO '<scheduler_user>'@'<host>';
```

## Leave Types by Location

| Location | Leave Types |
|----------|------------|
| Sri Lanka (& others) | Casual, Maternity, Paternity, Lieu |
| France | Congés Payés (25d, Jun–May), RTT (9d), Sick (sick note required), Compassionate, Other Authorized (lead approval), Maternity, Paternity, Lieu |
| Spain | Annual (23d), Casual, Sick, Maternity, Paternity, Lieu |

## Key API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/user-info` | Current user info (includes `location`) |
| GET | `/employees/{email}/leave-entitlement` | Leave balance for a given employee |
| POST | `/leaves` | Submit a leave request |
| GET | `/leaves` | Get leave history |
| POST | `/leaves/sick-leave` | Submit France sick leave with its sick note (JSON: `leave` and `sickNote` as base64 text) |
| GET | `/leaves/{id}/sick-note` | Download a sick note (the applicant or `sickNoteRoles` only; audited) |
| GET | `/sick-notes` | List sick notes overlapping `startDate`–`endDate` (`sickNoteRoles` only) |
| POST | `/leaves/{id}/{action}` | Lead approves or rejects; optional `{reason}` body, required for rejecting Other Authorized Leave |
| GET | `/app-configs` | App configuration |

## Other Authorized Leave approval

France only. Compassionate Leave is approved automatically. Other Authorized Leave is saved as pending and the
applicant's current lead (HR entity service) is emailed a link (`otherAuthorizedApprovalUrl`) to approve or reject it.

- The applicant must give a reason (the leave comment, stored in `submit_note`); a blank one is refused with a 400.
  The reason is always private: the backend saves it with `public_submit_note = 0`, whatever the request says. The
  lead reads it in the approval email, and after approval the comment email goes only to the applicant, their lead
  and the people they added, never to `emailGroupToNotify` or `defaultRecipients`.
- Rejecting requires a reason of 1–500 characters, which is sent to the applicant.
- A pending request blocks overlapping leave requests.
- The applicant can withdraw a pending request. The applicant and their current lead in HR (or the stored approver
  when HR has none) are told it was withdrawn.
- If the request is still pending, the lead is reminded by the [Approval Reminder Job](#approval-reminder-job); with no
  lead in HR, or with the applicant no longer in HR, People Operations is alerted.
- My History shows every leave's status (Pending, Approved, Rejected, Cancelled) to everyone.

## Sick Notes

France sick leave requires a sick note (PDF, JPG or PNG, up to 5 MB), uploaded with the request.

- **Upload**: the note is sent as base64 text in the JSON body, not as a multipart file. Cloudflare in front of
  `apis.wso2.com` answers a request body carrying raw binary with a bot challenge (403, `cf-mitigated: challenge`,
  no CORS header), which a browser request cannot pass.

- **Encryption**: stored encrypted with AES-256-GCM in `leave_attachments`, using `sickNoteEncryptionKey`. Never
  attached to emails.
- **Access**: only the applicant and members of `authorizedRoles.sickNoteRoles` can download a note.
- **Audit**: every download is recorded in `leave_attachment_downloads`.
- **Retention**: the [Sick Note Retention Job](#sick-note-retention-job) clears the content after
  `sickNoteRetentionInDays` and for cancelled leaves, keeping the row.

## Release 1.2.0 notes

1. Run `backend/resources/leave_app_update_v1.2.0.sql` before deploying the backend.
2. Give the scheduler's database user `SELECT` and `UPDATE` on `leave_attachments`, plus `SELECT` and the
   `approval_reminder_sent_on` `UPDATE` on `leave_submissions` (see
   [Scheduler Database Access](#scheduler-database-access)).
3. Set all new required configs: backend `sickNoteEncryptionKey`, `otherAuthorizedApprovalUrl`,
   `authorizedRoles.sickNoteRoles`; scheduler `approvalReminderFirstDelayInDays`, `approvalReminderIntervalInDays`,
   `approvalPageUrl`, `sickNoteRetentionInDays`. A missing one stops the service or scheduler at startup.

## Sabbatical Leave Rules

- Eligible after 7 years of continuous service, or 7 years after the last sabbatical ended (`sabbaticalLeaveEligibilityDuration`).
- Job band 5 and above (`sabbaticalLeaveMinJobBand`); employees with no job band on record cannot apply.
- At most 6 weeks (`sabbaticalLeaveMaxApplicationDuration`).
- The applicant must acknowledge the planning and handover responsibility when submitting, and the lead must confirm
  that plans are in place when approving.
- The employee's current lead is reminded 4 weeks before the leave starts (see [Sabbatical Reminder Job](#sabbatical-reminder-job), part of the [Leave Scheduler](#leave-scheduler)).

## Project Structure

```
backend/
  service.bal              # HTTP endpoints
  leave_calculation.bal    # Leave entitlement logic
  enum.bal                 # EmployeeLocation enum
  types.bal                # LeavePolicy, LeaveEntitlement, UserInfo
  utils.bal                # Period boundary helpers
  modules/
    database/              # MySQL queries and types
    employee/              # HR Entity GraphQL client
    authorization/         # JWT auth and RBAC
    email/                 # Email notifications
    calendar_events/       # Google Calendar integration

webapp/src/
  types/types.ts           # Enums (LeaveType, EmployeeLocation), interfaces
  services/leaveService.ts # API call functions
  slices/                  # Redux state (user, leave, auth, config)
  view/
    GeneralLeave/          # Leave submission form
      component/
        LeaveSelection.tsx        # Dynamic leave type icons
        LeaveBalanceSummary.tsx    # Balance panel (France/Spain)
        LeaveDateSelection.tsx    # Date pickers
    LeaveHistory/          # Leave history table
    LeadReport/            # Manager report view
    SabbaticalLeave/       # Sabbatical leave flow

leave-scheduler/           # Daily job runner (Choreo Scheduled Task)
  main.bal                 # Entry point: runs every job in turn
  functions.bal            # Jobs: sabbatical reminder, approval reminder, sick note retention
  modules/
    database/              # Due-reminder query and sent marker
    employee/              # HR Entity GraphQL client (employee name)
    email/                 # Reminder template and sending
```
