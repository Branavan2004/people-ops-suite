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

import { describe, expect, it } from "vitest";

import { LeaveType, Status } from "@/types/types";
import {
  HISTORY_STATUSES,
  canCancelLeave,
  canDownloadSickNote,
  leaveTypeLabel,
  needsReason,
  needsSickNote,
  rejectionReasonProblem,
  sickNoteProblem,
} from "@utils/leaveRules";

const MB = 1024 * 1024;
const TYPES = ["application/pdf", "image/jpeg", "image/png"];
const file = (name: string, type: string, size: number) =>
  new File([new Uint8Array(size)], name, { type });

describe("leaveTypeLabel", () => {
  it("names the new France types", () => {
    expect(leaveTypeLabel("other_authorized")).toBe("Other Authorized Leave");
    expect(leaveTypeLabel("compassionate")).toBe("Compassionate Leave");
  });
  it("keeps today's labels for existing types", () => {
    expect(leaveTypeLabel("casual")).toBe("Casual Leave");
    expect(leaveTypeLabel("conges_payes")).toBe("Congés Payés");
  });
});

describe("sickNoteProblem", () => {
  it("accepts a PDF, JPG or PNG up to the limit", () => {
    expect(sickNoteProblem(file("note.pdf", "application/pdf", 5 * MB), 5 * MB, TYPES)).toBe("");
    expect(sickNoteProblem(file("scan.JPG", "image/jpeg", 10), 5 * MB, TYPES)).toBe("");
  });
  it("refuses empty, oversized and other files", () => {
    expect(sickNoteProblem(file("note.pdf", "application/pdf", 0), 5 * MB, TYPES)).toBe(
      "This file is empty.",
    );
    expect(sickNoteProblem(file("note.pdf", "application/pdf", 5 * MB + 1), 5 * MB, TYPES)).toBe(
      "This file is larger than 5.0 MB.",
    );
    expect(sickNoteProblem(file("note.docx", "application/msword", 10), 5 * MB, TYPES)).toBe(
      "Send a PDF, JPG or PNG file.",
    );
  });
  it("trusts the reported type, and the name only when no type is reported", () => {
    expect(sickNoteProblem(file("note.pdf", "application/msword", 10), 5 * MB, TYPES)).toBe(
      "Send a PDF, JPG or PNG file.",
    );
    expect(sickNoteProblem(file("note.pdf", "", 10), 5 * MB, TYPES)).toBe("");
    expect(sickNoteProblem(file("scan.png", "image/png", 10), 5 * MB, TYPES)).toBe("");
  });
});

describe("rejectionReasonProblem", () => {
  it("needs 1 to 500 characters after trimming", () => {
    expect(rejectionReasonProblem("   ")).toBe("Enter a reason for rejecting this request.");
    expect(rejectionReasonProblem("a".repeat(500))).toBe("");
    expect(rejectionReasonProblem("a".repeat(501))).toBe(
      "The reason can be at most 500 characters.",
    );
  });
});

describe("canCancelLeave", () => {
  const today = new Date("2026-10-26T09:00:00");
  it("allows approved and pending leave within the 30-day window", () => {
    expect(canCancelLeave(Status.APPROVED, "2026-10-01", today)).toBe(true);
    expect(canCancelLeave(Status.PENDING, "2026-11-10", today)).toBe(true);
  });
  it("never offers cancel on finished or old leave", () => {
    expect(canCancelLeave(Status.CANCELLED, "2026-11-10", today)).toBe(false);
    expect(canCancelLeave(Status.REJECTED, "2026-11-10", today)).toBe(false);
    expect(canCancelLeave(Status.APPROVED, "2026-09-20", today)).toBe(false);
  });
  it("always lets a pending request be withdrawn, however long ago it started", () => {
    expect(canCancelLeave(Status.PENDING, "2026-09-16", today)).toBe(true);
    expect(canCancelLeave(Status.APPROVED, "2026-09-16", today)).toBe(false);
  });
});

describe("history and sick notes", () => {
  it("shows every status in My History", () => {
    expect(HISTORY_STATUSES).toEqual([
      Status.APPROVED,
      Status.PENDING,
      Status.REJECTED,
      Status.CANCELLED,
    ]);
  });
  it("needs a note only for sick leave in France", () => {
    expect(needsSickNote("France", LeaveType.SICK)).toBe(true);
    expect(needsSickNote("Spain", LeaveType.SICK)).toBe(false);
    expect(needsSickNote(null, LeaveType.SICK)).toBe(false);
  });
  it("needs a reason only for Other Authorized Leave", () => {
    expect(needsReason(LeaveType.OTHER_AUTHORIZED)).toBe(true);
    expect(needsReason(LeaveType.COMPASSIONATE)).toBe(false);
    expect(needsReason(LeaveType.SICK)).toBe(false);
  });
  it("offers the sick note download only until the note is deleted", () => {
    expect(canDownloadSickNote(true, null)).toBe(true);
    expect(canDownloadSickNote(true, "2026-10-20T02:00:00")).toBe(false);
    expect(canDownloadSickNote(false, null)).toBe(false);
  });
});
