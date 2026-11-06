# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`people-app` is an HR/People Operations application with four distinct sub-projects:

- **`backend/`** — Ballerina HTTP service (port 9090) for employee data management
- **`webapp/`** — Legacy React SPA (Create React App + react-app-rewired) — the primary admin UI
- **`microapp/`** — Modern embeddable React widget (Vite + React 19) for employee self-service features
- **`people-scheduler/`** — Standalone Ballerina package deployed as a WSO2 Choreo Scheduled Task; runs all scheduled People App background jobs from one `main()` entry point. Job orchestration logic (e.g. `runLeaverTransition()`) lives in root-level files like `functions.bal`, invoked from `main.bal`. All database access (queries, types, functions) lives in `modules/database/`; all email concerns (client, templates, notification-sending) live in `modules/email/` — these are the only two modules, shared across every job rather than split per job. Currently runs the leaver auto-transition job (transitions "Marked leaver" employees to "Left" once their final day of employment is over, and emails a summary), the scheduled-change job (applies a change once its effective date begins), and the joiner activation job (moves "New joiner" employees — onboarded with a future start date — to "Active" once that date begins, and emails a summary naming any still on the `future-joiner@wso2.com` placeholder email). Every date is read where the employee works: the timezone of their company + work location in `companies_allowed_locations.time_zone`, falling back to `Asia/Colombo` when none matches. The backend uses the same local date to decide New joiner vs Active at onboarding and to accept a scheduled change's date as a future one. No HTTP listener, no in-repo scheduling — Choreo's cron config controls run frequency, and it runs hourly at 35 minutes past (`35 * * * *`): within five minutes of midnight for half-hour offsets like Sri Lanka's and India's, and within 35 minutes everywhere else. Run locally with `cd people-scheduler && bal build` / `bal run`.

---

## Commands

### Backend (Ballerina)

```bash
cd backend
bal build          # compile
bal run            # run service (port 9090)
```

Copy `Config.toml.local` to `Config.toml` and fill in DB credentials and role names before running. The full `Config.toml` also requires `ADMIN_ROLE` and the `[people.wso2_coin]` section (blockchain `transactionEndpoint`, `clientAuthConfig` OAuth credentials, and `parkingSheetConfig` for Google Sheets) — see the checked-in `Config.toml.local` for the complete shape of all required sections.

### Webapp (Legacy CRA)

```bash
cd webapp
yarn install
yarn start         # dev server
yarn build         # production build
yarn test          # run tests (Jest + Testing Library)
yarn test -- --testPathPattern=<file>   # single test file
yarn analyze       # bundle analysis
```

Create `.env` in `webapp/` with: `APP_NAME`, `APP_DOMAIN`, `ASGARDEO_BASE_URL`, `ASGARDEO_CLIENT_ID`, `ASGARDEO_REVOKE_ENDPOINT`, `AUTH_SIGN_IN_REDIRECT_URL`, `AUTH_SIGN_OUT_REDIRECT_URL`, `REACT_APP_BACKEND_BASE_URL`.

ESLint config is inlined in `package.json` (no separate `.eslintrc` file).

### Microapp (Vite)

```bash
cd microapp
npm install
npm run dev        # dev server (port 3000)
npm run build      # production build (tsc -b && vite build)
npm run lint       # eslint
```

Runtime config injected via `window.config`. Required keys: `CLIENT_ID`, `SIGN_IN_REDIRECT_URL`, `SIGN_OUT_REDIRECT_URL`, `ASGARDEO_BASE_URL`, `IS_MICROAPP`, `BACKEND_BASE_URL`.

---

## Architecture

### Backend

- Ballerina 2201.12.7, organized as package `wso2_open_operations/people`
- Seven modules:
  - **`authorization`** — `JwtInterceptor` reads the `x-jwt-assertion` header, decodes the JWT, validates group membership, and stores `CustomJwtPayload` in the request context. Roles configured via `Config.toml`: `EMPLOYEE_ROLE`, `ADMIN_ROLE`, and `SERVICE_DESK_ROLE`.
  - **`database`** — MySQL client, all DB queries (`db_queries.bal`), DB functions (`db_functions.bal`), types, enums, and utils.
  - **`email`** — Email notification client; sends alerts via an external email service for onboarding events (e.g., failed Asgardeo group assignments).
  - **`qr`** — QR code generation for employees (`qr.bal`, `clients.bal`, `types.bal`).
  - **`scim`** — Asgardeo SCIM client for user and group management in the internal org; used during employee onboarding and bulk provisioning.
  - **`promotion`** — Read-only client for the separate HRIS database (`promotionDbConfig`), supplying approved promotion history to the employee history timeline. Kept apart from `database` because it is a second datasource: its own client, config and types, so the dependency can be replaced or removed without touching the primary database module.
  - **`wso2_coin`** — Car park reservation + O2C payment integration. Bundles the blockchain transaction client (`transaction.bal`, `clients.bal`), Google Sheets parking-record sync (`parkingSheet.bal`), shared types/constants, and admin scripts. Exposes config values like `masterWalletAddress`, `reservationWindowStartHour/EndHour`, and `pendingReservationExpiryMinutes` consumed directly from `service.bal`. The microapp's parking booking flow (`/services/parking/*`) is the frontend surface for this module.
- Every resource function in `service.bal` extracts `userInfo` from `ctx` and checks role permissions before executing business logic.
- Employee Hub dashboard endpoints (read-only, admin-only): `GET /intern-profiles` (intern roster; university comes from the `internship` table) and `GET /employee-hub/employees` (current staff and non-intern leavers). Both depend on the `internship` table from `people_app_table_update_v1.4.2.sql`; the core employee search/detail queries do not.
- Four privilege levels — `EMPLOYEE_PRIVILEGE`, `LEAD_PRIVILEGE`, `SERVICE_DESK_PRIVILEGE`, and `ADMIN_PRIVILEGE` — are returned to the frontend in `/user-info`.
- Database schema is managed via SQL files in `backend/resources/` (initial creation script + numbered migration files).

### Webapp

**State management:** Redux Toolkit with these slices in `src/slices/`:
- `authSlice` — Asgardeo auth state, roles (`Role.EMPLOYEE | Role.LEAD | Role.ADMIN`), and app mode (`active | maintenance`). The Lead role has permissions between Employee and Admin; exact behavior is driven by backend privilege checks and route guards.
- `userSlice` — logged-in user's employee info fetched from `/user-info`
- `employeeSlice` — employee list, selected employee details
- `employeePersonalInfo` — personal info for selected employee
- `organizationSlice` — org hierarchy data (BUs, teams, sub-teams, etc.). All fetch thunks share a single `state.state` field — any pending thunk sets the entire slice to `loading`.
- `masterDataSlice` — CRUD state for org master data (entities + parent/child mappings) backing the `view/masterData/` admin screens (`MasterDataView`, `EntityTab`, `EntityDialog`, `MappingDialog`, `HierarchyView`).
- `bulkOnboardingSlice` — state for bulk CSV employee upload: tracks created/skipped counts, per-row validation errors, SCIM provisioning errors, and group assignment warnings.
- `employeeHubSlice` — Employee Hub dashboard data: intern roster (`GET /intern-profiles`) and employees/leavers (`GET /employee-hub/employees`). Its row types (`InternRow`, `EmployeeRow`) live in the slice file. Each fetch runs once and is cached; `{ force: true }` refetches. Read via `@hooks/useEmployeeHub`; fetched on mount by `@hooks/useEmployeeHubBootstrap`.
- `commonSlice` — snackbar/notification queue
- `configSlice` — app config from backend

**Auth flow:** `AuthProvider` (Asgardeo) → `AppAuthProvider` (`src/context/AuthContext.tsx`) → dispatches `loadPrivileges` thunk → roles stored in `authSlice` → `AppHandler` renders routes based on roles. Idle timer triggers auto-logout after 30 minutes.

**API service** (`src/utils/apiService.ts`): Singleton Axios instance with retry-axios (3 retries, 401 triggers token refresh). Uses a per-endpoint `CancelToken` map — any new request to the same URL automatically cancels the previous in-flight request to that URL.

**Routing:** `src/route.ts` defines `RouteObjectWithRole[]` where each route has `allowRoles`. `getActiveRoutesV2()` filters routes by user roles. Views in `src/view/` (employees, me, cases, help, reports, masterData, employeeHub).

**Path aliases** (defined in `tsconfig.paths.json`, applied via `config-overrides.js` with react-app-rewired):
- `@src/*` → `src/`
- `@app/*` → `src/app/`
- `@component/*` → `src/component/`
- `@config/*` → `src/config/`
- `@context/*` → `src/context/`
- `@layout/*` → `src/layout/`
- `@slices/*` → `src/slices/`
- `@view/*` → `src/view/`
- `@utils/*` → `src/utils/`
- `@hooks/*` → `src/hooks/`

**Runtime config:** All env vars are injected via `window.config` (not `process.env` at build time for the deployed app). `src/config/config.ts` reads from `window.config` with fallback to empty strings.

**UI stack:** MUI v5, Emotion, Tailwind CSS v3, notistack for snackbars, Formik + Yup for forms. Dark/light theme via `src/theme.ts`.

### Microapp

**Purpose:** An embeddable widget that integrates into a host application (via the microapp bridge) rather than operating as a standalone app. It uses `HashRouter` so it can be embedded within another app's URL space.

**Auth:** Does not handle Asgardeo auth directly. Gets the JWT token from the parent React Native host via `src/components/microapp-bridge/` (`window.nativebridge.requestToken()` / `resolveToken()` callback). The `IS_MICROAPP` flag in `window.config` switches between embedded and standalone modes.

**Data fetching:** TanStack React Query (no Redux). `QueryClientProvider` wraps the app in `main.tsx`.

**Routing:** HashRouter with pages for the self-service dashboard (`Home`) and a multi-step parking booking flow: `VehicleManagement` (`/services/vehicles`), `ParkingSlotSelection` (`/services/parking`), `ParkingBookingSummary`, `ParkingBookingConfirmation`, and `MyParkingBookings`. A `ParkingWalletReturnResume` component handles deep-link resume after the O2C wallet flow. The parking flow consumes the backend's `wso2_coin` module endpoints.

**Path alias:** `@/` → `src/` (configured in `vite.config.ts`).

**UI stack:** MUI v7, Tailwind CSS v4, Motion (Framer Motion) for page transitions.

---

## Role-Based Access

### Backend privilege levels

The backend issues three privilege levels, returned as an array in the `/user-info` response:

| Constant | Value | How it is granted |
|---|---|---|
| `EMPLOYEE_PRIVILEGE` | 987 | Every authenticated user |
| `LEAD_PRIVILEGE` | 993 | Dynamically: `database:isLead(email)` — no static IAM group |
| `SERVICE_DESK_PRIVILEGE` | 991 | IAM group membership (`SERVICE_DESK_ROLE` in `Config.toml`) |
| `ADMIN_PRIVILEGE` | 999 | IAM group membership (`ADMIN_ROLE` in `Config.toml`) |

`LEAD_ROLE` is **not** configured in `Config.toml`; lead status is resolved at request time from the DB.

For employee-list endpoints the backend checks `leadOnly` and `directReports` in the request payload. The two flags operate independently:

- **`leadOnly = true`** (always set by `MyTeamTable`, never by the admin view): the backend scopes the query to employees who are subordinates of the caller. Within that scoped result, the `directReports` filter further narrows the set:
  - `directReports = true` — return only *direct* reports of the caller.
  - `directReports = false` (default) — return *all* subordinates of the caller (direct and indirect).
- **`leadOnly = false`** (admin path only): no caller-scoping is applied; all employees matching the other filters are returned. A lead user never sends this value.

### Frontend roles (`Role` enum in `authSlice`)

`loadPrivileges` thunk maps the privilege array → `Role[]`:

- `Role.EMPLOYEE` — always added
- `Role.LEAD` — added when the privileges array contains `LEAD_PRIVILEGE` (993)
- `Role.SERVICE_DESK` — added when the privileges array contains `SERVICE_DESK_PRIVILEGE` (991)
- `Role.ADMIN` — added when the privileges array contains `ADMIN_PRIVILEGE` (999)

A user may hold more than one role simultaneously (e.g., `[EMPLOYEE, LEAD]` or `[EMPLOYEE, LEAD, ADMIN]`).

### Route access matrix

| Route | `allowRoles` | `excludeRoles` | Visible to |
|---|---|---|---|
| `/` (Me) | `ADMIN, EMPLOYEE` | — | Everyone |
| `/employees` (parent) | `ADMIN` | — | Admins |
| `/employees/view` (All) | `ADMIN` | — | Admins |
| `/employees/my-team` *(nested)* | `LEAD` | — | Admin+Lead (nested under Employees sidebar group) |
| `/employees/my-team` *(top-level)* | `LEAD` | `ADMIN` | Lead-only users (shown as top-level sidebar item) |
| `/onboarding` | `ADMIN` | — | Admins |
| `/employees/:employeeId` | `ADMIN, LEAD` | — | Admins and Leads (not in sidebar) |
| `/employees/:employeeId/edit` | `ADMIN` | — | Admins only (not in sidebar) |
| `/reports` (parent) | `ADMIN, SERVICE_DESK` | — | Admins and Service Desk |
| `/reports/active-employees` | `ADMIN` | — | Admins only |
| `/reports/inactive-employees` | `ADMIN` | — | Admins only |
| `/reports/qr-codes` | `ADMIN, SERVICE_DESK` | — | Admins and Service Desk |
| `/master-data` | `ADMIN` | — | Admins only |
| `/employee-hub` (parent) | `ADMIN` | — | Admins only (redirects to `/employee-hub/employees`) |
| `/employee-hub/employees` (Permanent) | `ADMIN` | — | Admins only |
| `/employee-hub/interns` (Interns) | `ADMIN` | — | Admins only |

The dual `/employees/my-team` route entries ensure that lead+admin users see **My Team** nested under the **Employees** group, while lead-only users see it as a standalone top-level entry. The `excludeRoles` guard on the top-level entry prevents duplication for admin+lead users.

---

## Coding Standards & Reuse Guidelines

### Webapp (React)

- **Reuse components first** — check `src/component/` before creating a new one; use existing MUI components as the base.
- **API endpoints** — always add new URLs to `AppConfig.serviceUrls` in `src/config/config.ts`; never hard-code URLs in components or thunks.
- **HTTP calls** — always use `APIService.getInstance()`; never import raw axios or fetch.
- **Redux thunks** — follow the existing `createAsyncThunk` pattern: check `isCancel(error)` first, dispatch `enqueueSnackbarMessage` on error, return `rejectWithValue`.
- **Async state** — use the existing `State` enum (`idle | loading | success | failed`) for every async operation in a slice.
- **Types** — add new interfaces/types in the relevant slice file alongside existing ones; use `field: T | null` (not `field?: T`) for nullable fields.
- **Path aliases** — always use `@slices/`, `@component/`, `@utils/`, `@view/`, etc.; never use relative `../../` imports.
- **Styling** — MUI `sx` prop + `useTheme()` for component styles; Tailwind utility classes for layout.
- **Forms** — reuse Formik + Yup; do not introduce other form libraries.

### Backend (Ballerina)

- **Config** — every new `configurable` value must be added to `Config.toml.local` (with an empty/default placeholder) in the same commit.
- **Module structure** — keep resource functions in `service.bal`; put business logic in the appropriate module.
- **Helpers** — reuse existing `authorization` and `database` module functions before writing new ones.
