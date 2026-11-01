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

// Sources the Interns tab's full roster from people-app's real backend
// (GET /intern-profiles). Only university comes from the `internship` table;
// everything else is the intern's `employee` row.

import { APIService } from "@utils/apiService";
import { AppConfig } from "@config/config";
import type { InternHubData, InternRow, InternStatus } from "@slices/employeeHubSlice/employeeHub";
import { parseDate } from "./dateHelpers";

// Mirrors database:InternProfile in the backend (modules/database/types.bal).
interface InternProfileApiRow {
  id: number;
  employeeId: string | null;
  email: string | null;
  name: string | null;
  gender: string | null;
  university: string | null;
  mentorEmail: string | null;
  businessUnit: string | null;
  team: string | null;
  subTeam: string | null;
  joinedDate: string | null;
  endDate: string | null;
  employeeStatus: string | null;
  employmentType: string | null;
}

// Someone whose employment type is no longer INTERNSHIP has moved on to a
// permanent/probation role, so their internship is over. Their start/agreement
// end dates on that row belong to the new role, not the internship.
function isStillInternshipRow(row: InternProfileApiRow): boolean {
  return (row.employmentType || "").toUpperCase() === "INTERNSHIP";
}

// An internship is active only while today is between its start and end
// dates. employee_status isn't always flipped to "Left" once the agreement
// end date passes, so the date alone decides that the internship is over.
function statusFor(row: InternProfileApiRow, joinedDate: Date | null, endDate: Date | null): InternStatus {
  if (!isStillInternshipRow(row)) return "Ended";
  if ((row.employeeStatus || "").toLowerCase() === "left") return "Ended";
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  if (endDate && endDate < today) return "Ended";
  if (joinedDate && joinedDate > today) return "Not Started";
  return "In Progress";
}

function mapInternProfileToRow(row: InternProfileApiRow): InternRow {
  const internshipRow = isStillInternshipRow(row);
  const joinedDate = internshipRow ? row.joinedDate || null : null;
  const endDate = internshipRow ? row.endDate || null : null;

  return {
    id: String(row.id),
    employeeId: row.employeeId || "",
    name: row.name || "",
    email: row.email || "",
    gender: row.gender || "",
    mentorEmail: row.mentorEmail || "",
    bu: row.businessUnit || "",
    team: row.team || "",
    subTeam: row.subTeam || "",
    university: row.university || "",
    joinedDate,
    endDate,
    status: statusFor(row, parseDate(joinedDate), parseDate(endDate)),
  };
}

/** Fetches the full intern roster from GET /intern-profiles. */
export async function loadInternHubDataFromApi(): Promise<InternHubData> {
  const response = await APIService.getInstance().get(AppConfig.serviceUrls.internProfiles);
  const rows = (response.data || []) as InternProfileApiRow[];
  return { interns: rows.map(mapInternProfileToRow) };
}
