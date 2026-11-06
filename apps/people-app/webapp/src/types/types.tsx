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

export enum EmployeeStatus {
  Active = "Active",
  Left = "Left",
  MarkedLeaver = "Marked leaver",
  // Onboarded with a start date still to come; the scheduler makes them Active on that date.
  NewJoiner = "New joiner",
}

// Statuses of people employed now or about to be — the default scope of the employee lists.
// New joiner is included so that turning off "Exclude future joiners" shows them; with that
// filter on (the default) their future start date keeps them out.
export const CURRENT_EMPLOYEE_STATUSES: readonly EmployeeStatus[] = [
  EmployeeStatus.Active,
  EmployeeStatus.MarkedLeaver,
  EmployeeStatus.NewJoiner,
];

// Whether a status filter is exactly the default current-employee scope, in any order.
export const isCurrentEmployeeStatusSet = (statuses: readonly string[]): boolean =>
  statuses.length === CURRENT_EMPLOYEE_STATUSES.length &&
  CURRENT_EMPLOYEE_STATUSES.every((status) => statuses.includes(status));

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
  discard = "discard",
}

export interface CommonCardProps {
  actions: React.ReactElement<any, string | React.JSXElementConstructor<any>>;
  dataCardIndex: number;
}

export interface EmergencyContact {
  name: string | null;
  relationship: string | null;
  telephone: string | null;
  mobile: string | null;
}

export interface CreateEmployeeFormValues {
  personalInfo: {
    nicOrPassport: string;
    firstName: string;
    lastName: string;
    fullName: string;
    title: string;
    dob: string | null;
    gender: string;
    personalEmail: string | null;
    personalPhone: string | null;
    residentNumber: string | null;
    addressLine1: string | null;
    addressLine2: string | null;
    city: string | null;
    stateOrProvince: string | null;
    postalCode: string | null;
    country: string | null;
    nationality: string;
    emergencyContacts: EmergencyContact[];
  };
  workEmail: string;
  epf: string;
  businessUnitId: number;
  teamId: number;
  subTeamId: number;
  unitId: number;
  companyId: number;
  officeId: number;
  workLocation: string;
  employmentTypeId: number;
  startDate: string;
  probationEndDate: string | null;
  agreementEndDate: string | null;
  isRelocation: boolean;
  continuousServiceRecord?: number | null;
  managerEmail: string;
  additionalManagerEmail: string[];
  leadershipGroupIds: number[];
  careerFunctionId: number;
  designationId: number;
  secondaryJobTitle: string;
  jobRole: string;
  externalDesignation: string;
  houseId: number;
  employeeId?: string;
  /** University an intern attends; only shown and sent for the Internship type. */
  university: string;
  employeeStatus: EmployeeStatus | null;
  finalDayInOffice: string | null;
  finalDayOfEmployment: string | null;
  resignationReason: string | null;
}

export const emptyCreateEmployeeValues: CreateEmployeeFormValues = {
  personalInfo: {
    nicOrPassport: "",
    firstName: "",
    lastName: "",
    fullName: "",
    title: "",
    dob: null,
    gender: "",
    personalEmail: null,
    personalPhone: null,
    residentNumber: null,
    addressLine1: null,
    addressLine2: null,
    city: null,
    stateOrProvince: null,
    postalCode: null,
    country: null,
    nationality: "",
    emergencyContacts: [],
  },
  workEmail: "",
  epf: "",
  businessUnitId: 0,
  teamId: 0,
  subTeamId: 0,
  unitId: 0,
  companyId: 0,
  officeId: 0,
  workLocation: "",
  employmentTypeId: 0,
  startDate: "",
  probationEndDate: null,
  agreementEndDate: null,
  university: "",
  isRelocation: false,
  continuousServiceRecord: null,
  managerEmail: "",
  additionalManagerEmail: [],
  leadershipGroupIds: [],
  careerFunctionId: 0,
  designationId: 0,
  secondaryJobTitle: "",
  jobRole: "",
  externalDesignation: "",
  houseId: 0,
  employeeId: "",
  employeeStatus: null,
  finalDayInOffice: null,
  finalDayOfEmployment: null,
  resignationReason: null,
};

export interface ServiceLength {
  years: number;
  months: number;
}
