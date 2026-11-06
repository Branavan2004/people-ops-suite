// Copyright (c) 2025 WSO2 LLC. (https://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
import type { RouteObject } from "react-router-dom";

export type NavState = {
  hovered: number | null;
  active: number | null;
  expanded: number | null;
};

export enum State {
  failed = "failed",
  success = "success",
  loading = "loading",
  idle = "idle",
}

export enum ConfirmationType {
  update = "update",
  send = "send",
  upload = "upload",
  accept = "accept",
}

export enum PeriodType {
  ONE = "one",
  MULTIPLE = "multiple",
  HALF = "half",
}

export enum DayPortion {
  FULL = "full",
  FIRST = "first",
  SECOND = "second",
}

export enum DayPortionLabel {
  FULL = "Full Day",
  FIRST = "First Half",
  SECOND = "Second Half",
}

export interface RouteDetail {
  path: string;
  allowRoles?: string[];
  denyRoles?: string[];
  icon?: React.ReactElement<any, string | React.JSXElementConstructor<any>> | undefined;
  text?: string;
  children?: RouteObjectWithRole[];
  bottomNav?: boolean;
  element?: React.ReactNode;
}

export type RouteObjectWithRole = RouteObject & {
  allowRoles?: string[];
  denyRoles?: string[];
};

// Leave approval status.
export enum Status {
  PENDING = "PENDING",
  APPROVED = "APPROVED",
  REJECTED = "REJECTED",
  CANCELLED = "CANCELLED",
}

// Leave type.
export enum LeaveType {
  CASUAL = "casual",
  ANNUAL = "annual",
  SABBATICAL = "sabbatical",
  MATERNITY = "maternity",
  PATERNITY = "paternity",
  LIEU = "lieu",
  SICK = "sick",
  CONGES_PAYES = "conges_payes",
  RTT = "rtt",
  MEDICAL = "medical",
  NO_PAY = "no-pay",
  COMPASSIONATE = "compassionate",
  OTHER_AUTHORIZED = "other_authorized",
}

export enum LeaveLabel {
  CASUAL = "Casual/Annual",
  MATERNITY = "Maternity",
  PATERNITY = "Paternity",
  LIEU = "Lieu",
  SABBATICAL = "Sabbatical",
  SICK = "Sick Leave",
  CONGES_PAYES = "Congés Payés",
  RTT = "RTT",
  MEDICAL = "Medical",
  NO_PAY = "No-Pay",
  COMPASSIONATE = "Compassionate Leave",
  OTHER_AUTHORIZED = "Other Authorized Leave",
  SPAIN_ANNUAL = "Annual Leave",
  SPAIN_CASUAL = "Casual Leave",
  INDIA_ANNUAL = "Annual / Earned",
  INDIA_CASUAL = "Casual",
}

// Tooltip descriptions for leave types.
export const LeaveTooltip: Partial<Record<LeaveType, string>> = {
  [LeaveType.CONGES_PAYES]: "Paid Annual Leave",
  [LeaveType.RTT]: "Réduction du Temps de Travail",
  [LeaveType.SICK]: "Sick Leave",
  [LeaveType.COMPASSIONATE]: "Leave for a bereavement or a family emergency",
  [LeaveType.OTHER_AUTHORIZED]: "Other authorized absence approved by your manager",
};

// Leave Approval action.
export enum Action {
  APPROVE = "approve",
  REJECT = "reject",
}

// Sorting order.
export enum OrderBy {
  ASC = "ASC",
  DESC = "DESC",
}

// Leave validation types.
export interface LeaveValidationRequest {
  periodType: PeriodType;
  startDate: string;
  endDate: string;
  isMorningLeave: boolean | null;
}

// Leave validation response type.
export interface LeaveValidationResponse {
  workingDays: number;
  isValid: boolean;
  message?: string;
}

// Employee types.
export interface Employee {
  employeeId: string;
  firstName: string;
  lastName: string;
  workEmail: string;
  employeeThumbnail: string | null;
  employeeStatus?: string | null;
}
// Default mail type.
export interface DefaultMail {
  email: string;
  thumbnail: string;
}

// Default mail response type.
export interface CachedMail {
  mandatoryMails: DefaultMail[];
  optionalMails: DefaultMail[];
}

// Leave submission type.
export interface LeaveSubmissionRequest {
  periodType?: PeriodType;
  startDate: string;
  endDate: string;
  isMorningLeave?: boolean | null;
  comment: string;
  leaveType: LeaveType;
  emailRecipients?: string[];
  isPublicComment?: boolean;
}

// Leave submission response type.
export interface LeaveSubmissionResponse {
  success: boolean;
  message?: string;
  leaveId?: string;
}

// Payload for recording leave on behalf of an employee (People Ops only).
export interface OnBehalfLeaveRequest {
  employeeEmail: string;
  leaveType: LeaveType;
  startDate: string;
  endDate: string;
  periodType?: PeriodType;
  comment?: string;
  emailRecipients?: string[];
  isPublicComment?: boolean;
}

// Result of a validation-only on-behalf request, used for the live preview.
export interface OnBehalfLeavePreview {
  workingDays: number;
  hasOverlap: boolean;
  message?: string;
}

// Leave history response for a single leave.
export interface SingleLeaveHistory {
  id: number;
  email: string;
  approverEmail: string | null;
  leaveType: LeaveType;
  periodType: PeriodType;
  copyEmailList: string;
  notifyEveryone: boolean;
  submitComment: string;
  cancelComment: string;
  createdDate: string | null;
  updatedDate: string | null;
  emailId: string | null;
  emailSubject: string | null;
  isActive: boolean;
  startDate: string;
  endDate: string;
  startHalf: number | null;
  isEndHalf: number | null;
  canceledDate: string | null;
  numberOfDays: number;
  isPublicComment: boolean;
  calendarEventId: string | null;
  location: string;
  status: Status;
  rejectionReason: string | null;
  hasSickNote: boolean;
  sickNoteDeletedOn: string | null;
}

// Sick note summary (mirrors backend SickNoteSummary).
export interface SickNoteSummary {
  leaveId: number;
  email: string;
  startDate: string;
  endDate: string;
  numberOfDays: number;
  status: Status;
  uploadedAt: string;
  deletedAt: string | null;
  sizeBytes: number;
  contentType: string;
}

// Leave history response type.
export interface LeaveHistoryResponse {
  leaves: SingleLeaveHistory[];
}

// Employee status enum (mirrors backend EmployeeStatus).
export enum EmployeeStatus {
  ACTIVE = "Active",
  MARKED_LEAVER = "Marked leaver",
  LEFT = "Left",
}

// Query parameters for leave history request.
export interface LeaveHistoryQueryParam {
  email?: string;
  startDate?: string;
  endDate?: string;
  approverEmail?: string;
  leaveCategory?: LeaveType[];
  statuses?: Status[];
  limit?: number;
  offset?: number;
  orderBy?: OrderBy;
  employeeStatuses?: EmployeeStatus[];
  subordinatesLeaves?: boolean;
}

// Lead report request type.
export interface LeadReportRequest {
  startDate: string;
  endDate: string;
  isAdminView: boolean;
  employeeEmail?: string;
  employeeStatuses?: string[];
}

// Lead report response type.
export interface LeadReportResponse {
  [email: string]: {
    casual?: number;
    total?: number;
    totalExLieu?: number;
    lieu?: number;
    maternity?: number;
    paternity?: number;
    sabbatical?: number;
    conges_payes?: number;
    rtt?: number;
    spain_annual?: number;
    spain_casual?: number;
    sick?: number;
  };
}

// Approval response payload.
export interface ApprovalResponse {
  message: string;
}

// Eligibility response type.
export interface EligibilityResponse {
  employmentStartDate: string;
  lastSabbaticalLeaveEndDate: string;
}

// Sabbatical application request type.
export interface SabbaticalApplicationRequest {
  lastSabbaticalLeaveEndDate: string;
  startDate: string;
  endDate: string;
  additionalComment: string;
}

// Sabbatical application response type.
export interface SabbaticalApplicationResponse {
  message: string;
}

// App config response type.
export interface AppConfigResponse {
  isSabbaticalLeaveEnabled: boolean;
  sabbaticalLeavePolicyUrl: string;
  sabbaticalLeaveUserGuideUrl: string;
  sabbaticalLeaveEligibilityDuration: number;
  sabbaticalLeaveMaxApplicationDuration: number;
  sabbaticalLeaveMinJobBand: number;
  cachedEmails: CachedMail;
  // Leave types People Ops may record on behalf of an employee. Server-driven,
  // so enabling another type needs no frontend change.
  onBehalfAllowedLeaveTypes?: LeaveType[];
  sickNoteMaxBytes: number;
  sickNoteContentTypes: string[];
}

// Leave policy entitlement/consumed counts.
export interface LeavePolicy {
  annual?: number | null;
  casual?: number | null;
  congesPayes?: number | null;
  rtt?: number | null;
  sick?: number | null;
}

// Leave entitlement response for a single year/period.
export interface LeaveEntitlement {
  year: number;
  location: string | null;
  leavePolicy: LeavePolicy;
  policyAdjustedLeave: LeavePolicy;
  periodStart?: string | null;
  periodEnd?: string | null;
}

// Employee location constants.
export enum EmployeeLocation {
  LK = "Sri Lanka",
  FR = "France",
  ES = "Spain",
  IN = "India",
}
