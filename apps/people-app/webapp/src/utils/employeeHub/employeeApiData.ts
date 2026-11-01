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

// Sources the Dashboard's "Permanent Employees" tab from
// GET /employee-hub/employees (admin-only). Interns are left out here; the
// Interns tab reads them from GET /intern-profiles instead.

import { APIService } from "@utils/apiService";
import { AppConfig } from "@config/config";
import type { EmployeeHubData, EmployeeRow } from "@slices/employeeHubSlice/employeeHub";

// Mirrors database:EmployeeHubEmployee in the backend (modules/database/types.bal).
interface HubApiEmployee {
  employeeId: string;
  firstName: string | null;
  lastName: string | null;
  workEmail: string | null;
  gender: string | null;
  designation: string | null;
  jobBand: number | null;
  businessUnit: string | null;
  team: string | null;
  subTeam: string | null;
  managerEmail: string | null;
  workLocation: string | null;
  startDate: string | null;
  probationEndDate: string | null;
  agreementEndDate: string | null;
  employeeStatus: string | null;
  employmentType: string | null;
  university: string | null;
  resignationDate: string | null;
  finalDayOfEmployment: string | null;
}

const INTERNSHIP_TYPE = "INTERNSHIP";

// employment_type.name is stored upper case ("PERMANENT", "CONSULTANCY",
// "ADVISORY CONSULTANT", "PART TIME CONSULTANCY", ...). Kept as the real
// value rather than collapsed into Full-time/Contract, just title-cased for
// display.
function formatEmploymentType(name: string | null | undefined): string {
  const s = (name || "").trim();
  if (!s) return "Unspecified";
  return s.toLowerCase().replace(/(^|[\s.-])(\w)/g, (_, sep, c) => sep + c.toUpperCase());
}

function mapToEmployeeRow(e: HubApiEmployee): EmployeeRow {
  return {
    employeeId: e.employeeId,
    name: `${e.firstName || ""} ${e.lastName || ""}`.trim(),
    email: e.workEmail || "",
    gender: e.gender || "",
    designation: e.designation || "",
    team: e.team || "",
    bu: e.businessUnit || "",
    reportingManager: e.managerEmail || "",
    joinDate: e.startDate || null,
    employmentType: formatEmploymentType(e.employmentType),
    jobBand: e.jobBand ?? null,
    status: e.employeeStatus || "",
    location: e.workLocation || "",
    resignationDate: e.resignationDate || null,
    finalDayOfEmployment: e.finalDayOfEmployment || null,
    probationEndDate: e.probationEndDate || null,
  };
}

const isIntern = (e: HubApiEmployee) => e.employmentType?.toUpperCase() === INTERNSHIP_TYPE;

export async function loadEmployeeHubDataFromApi(): Promise<EmployeeHubData> {
  const response = await APIService.getInstance().get(AppConfig.serviceUrls.employeeHubEmployees);
  const apiEmployees = (response.data?.employees || []) as HubApiEmployee[];
  const apiLeavers = (response.data?.leavers || []) as HubApiEmployee[];

  return {
    employees: apiEmployees.filter((e) => !isIntern(e)).map(mapToEmployeeRow),
    leavers: apiLeavers.map(mapToEmployeeRow),
  };
}
