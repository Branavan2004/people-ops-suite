// Copyright (c) 2026 WSO2 LLC. (https://www.wso2.com).
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

import { EmployeeLocation, LeaveLabel, LeaveType, Status } from "@/types/types";

const MB = 1024 * 1024;
const CANCEL_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;
export const REJECTION_REASON_MAX = 500;
const SICK_NOTE_EXTENSIONS = ["pdf", "jpg", "jpeg", "png"];

const LEAVE_LABELS: Record<string, string> = {
  [LeaveType.CONGES_PAYES]: LeaveLabel.CONGES_PAYES,
  [LeaveType.COMPASSIONATE]: LeaveLabel.COMPASSIONATE,
  [LeaveType.OTHER_AUTHORIZED]: LeaveLabel.OTHER_AUTHORIZED,
};

/** Statuses shown in My History. */
export const HISTORY_STATUSES: Status[] = [
  Status.APPROVED,
  Status.PENDING,
  Status.REJECTED,
  Status.CANCELLED,
];

/** Display label for a leave type value. */
export function leaveTypeLabel(type: string): string {
  return (
    LEAVE_LABELS[type] ?? `${type.charAt(0).toUpperCase() + type.slice(1).toLowerCase()} Leave`
  );
}

/** Returns a message describing why a sick note file is not acceptable, or "" when it is. */
export function sickNoteProblem(file: File, maxBytes: number, contentTypes: string[]): string {
  if (file.size === 0) return "This file is empty.";
  if (file.size > maxBytes) return `This file is larger than ${(maxBytes / MB).toFixed(1)} MB.`;
  const extension = file.name.split(".").pop()?.toLowerCase() ?? "";
  // The name only counts when the browser reports no type, so a renamed file is caught here.
  const typeAllowed = file.type
    ? contentTypes.includes(file.type)
    : SICK_NOTE_EXTENSIONS.includes(extension);
  if (!typeAllowed) {
    return "Send a PDF, JPG or PNG file.";
  }
  return "";
}

/** Returns a message when a rejection reason is invalid, or "" when it is acceptable. */
export function rejectionReasonProblem(reason: string): string {
  const trimmed = reason.trim();
  if (!trimmed) return "Enter a reason for rejecting this request.";
  if (trimmed.length > REJECTION_REASON_MAX) {
    return `The reason can be at most ${REJECTION_REASON_MAX} characters.`;
  }
  return "";
}

/**
 * Approved leave can be cancelled unless it started more than 30 days ago. A pending request has not been decided,
 * so it can always be withdrawn; otherwise one its lead never decides would stay pending for good.
 */
export function canCancelLeave(status: Status, startDate: string, today: Date): boolean {
  if (status === Status.PENDING) return true;
  if (status !== Status.APPROVED) return false;
  const todayStart = new Date(today);
  todayStart.setHours(0, 0, 0, 0);
  const leaveStart = new Date(startDate);
  leaveStart.setHours(0, 0, 0, 0);
  return leaveStart.getTime() - todayStart.getTime() >= -CANCEL_WINDOW_MS;
}

/** Other Authorized Leave needs a reason, which the lead decides on. It is always kept private. */
export function needsReason(leaveType: LeaveType): boolean {
  return leaveType === LeaveType.OTHER_AUTHORIZED;
}

/** Sick leave taken in France needs a sick note. */
export function needsSickNote(location: string | null, leaveType: LeaveType): boolean {
  return location === EmployeeLocation.FR && leaveType === LeaveType.SICK;
}

/**
 * A sick note can be downloaded until it is deleted. A deleted note keeps its row, so `hasSickNote`
 * stays true after the deletion.
 */
export function canDownloadSickNote(
  hasSickNote: boolean,
  sickNoteDeletedOn: string | null,
): boolean {
  return hasSickNote && !sickNoteDeletedOn;
}
