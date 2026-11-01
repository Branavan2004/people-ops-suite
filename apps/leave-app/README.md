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

#### Running the Scheduler

1. Apply `backend/resources/leave_app_update_v1.1.1.sql` to the leave database (adds the reminder column).
2. Copy `leave-scheduler/Config.toml.local` to `leave-scheduler/Config.toml` and fill it in. In non-production
   environments keep `isDebug = true` with your address in `debugRecipients`: reminders then go only there, with no
   CC, and are not marked as sent.
3. Build and run:

```bash
cd leave-scheduler
bal build
bal run
```

## Leave Types by Location

| Location | Leave Types |
|----------|------------|
| Sri Lanka (& others) | Casual, Maternity, Paternity, Lieu |
| France | Congés Payés (25d, Jun–May), RTT (9d), Sick, Maternity, Paternity, Lieu |
| Spain | Annual (23d), Casual, Sick, Maternity, Paternity, Lieu |

## Key API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/user-info` | Current user info (includes `location`) |
| GET | `/employees/{email}/leave-entitlement` | Leave balance for a given employee |
| POST | `/leaves` | Submit a leave request |
| GET | `/leaves` | Get leave history |
| GET | `/app-configs` | App configuration |

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
  functions.bal            # Jobs: 4-week sabbatical reminder to the lead
  modules/
    database/              # Due-reminder query and sent marker
    employee/              # HR Entity GraphQL client (employee name)
    email/                 # Reminder template and sending
```
