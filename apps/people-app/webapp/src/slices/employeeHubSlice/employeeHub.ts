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

import { createSlice, createAsyncThunk } from "@reduxjs/toolkit";
import { HttpStatusCode, isCancel } from "axios";
import { State } from "@/types/types";
import { RootState } from "@slices/store";
import { enqueueSnackbarMessage } from "@slices/commonSlice/common";
import { loadInternHubDataFromApi } from "@utils/employeeHub/internApiData";
import { loadEmployeeHubDataFromApi } from "@utils/employeeHub/employeeApiData";

// Internship status, derived from the intern's employment type, status and dates
// (see statusFor in internApiData.ts).
export type InternStatus = "In Progress" | "Ended" | "Not Started";

// One row per person returned by GET /intern-profiles.
export interface InternRow {
  // employee.id
  id: string;
  employeeId: string;
  name: string;
  email: string;
  gender: string;
  mentorEmail: string;
  bu: string;
  team: string;
  subTeam: string;
  university: string;
  // Kept as the API's YYYY-MM-DD strings, not Date objects - Redux state must
  // stay serializable. Null once the person has moved on to another
  // employment type, since that row's dates belong to the new role.
  joinedDate: string | null;
  endDate: string | null;
  status: InternStatus;
}

// One row per non-intern employee returned by GET /employee-hub/employees.
export interface EmployeeRow {
  employeeId: string;
  name: string;
  email: string;
  gender: string;
  designation: string;
  team: string;
  bu: string;
  reportingManager: string;
  joinDate: string | null;
  employmentType: string;
  // designation.job_band - null when the designation has no band set.
  jobBand: number | null;
  // Real employee_status: "Active", "Marked leaver" or "Left".
  status: string;
  location: string;
  // From the `resignation` table - null for anyone who hasn't resigned.
  resignationDate: string | null;
  finalDayOfEmployment: string | null;
  probationEndDate: string | null;
}

export interface InternHubData {
  interns: InternRow[];
}

export interface EmployeeHubData {
  employees: EmployeeRow[];
  // Non-intern employees with status "Left" - the source for departure
  // counts and the historical headcount trend.
  leavers: EmployeeRow[];
}

export interface EmployeeHubState {
  // Every intern, whatever their status.
  interns: InternRow[];
  state: State;
  errorMessage: string | null;
  // Populated from GET /employee-hub/employees for the Dashboard's
  // "Permanent Employees" tab - not people-app's real `employee` slice.
  employees: EmployeeRow[];
  leavers: EmployeeRow[];
  employeesState: State;
  employeesErrorMessage: string | null;
  // True once the employee fetch has succeeded, so the UI can explain an
  // empty employee list instead of silently showing an empty state.
  employeesIsLive: boolean;
}

const initialState: EmployeeHubState = {
  interns: [],
  state: State.idle,
  errorMessage: null,
  employees: [],
  leavers: [],
  employeesState: State.idle,
  employeesErrorMessage: null,
  employeesIsLive: false,
};

// Both fetches load the whole roster, so they run once and the result is kept
// in the store: switching between the Permanent and Interns pages (or coming
// back from a profile) remounts the dashboard, and without this check every
// remount re-downloaded everything. `force` (the Refresh button) skips the
// cache; nothing ever starts a second copy while one is already running.
type HubFetchArg = { force?: boolean } | void;

const hubFetchCondition = (key: "state" | "employeesState") =>
  (arg: HubFetchArg, { getState }: { getState: () => unknown }) => {
    const current = (getState() as RootState).employeeHub[key];
    if (current === State.loading) return false;
    return !!arg?.force || current !== State.success;
  };

export const fetchInternHubData = createAsyncThunk(
  "employeeHub/fetchAll",
  async (_: HubFetchArg, { dispatch, rejectWithValue }) => {
    try {
      return await loadInternHubDataFromApi();
    } catch (error: any) {
      if (isCancel(error)) return rejectWithValue("cancelled");
      const errorMessage =
        error.response?.status === HttpStatusCode.InternalServerError
          ? "Error fetching intern data"
          : error.response?.data?.message ||
            error.message ||
            "An unknown error occurred while fetching intern data.";
      dispatch(
        enqueueSnackbarMessage({
          message: errorMessage,
          type: "error",
        }),
      );
      return rejectWithValue(errorMessage);
    }
  },
  { condition: hubFetchCondition("state") },
);

// Sources the "Permanent Employees" tab from GET /employee-hub/employees - see
// employeeApiData.ts. Admin-only.
export const fetchEmployeeHubData = createAsyncThunk(
  "employeeHub/fetchEmployees",
  async (_: HubFetchArg, { dispatch, rejectWithValue }) => {
    try {
      return await loadEmployeeHubDataFromApi();
    } catch (error: any) {
      if (isCancel(error)) return rejectWithValue("cancelled");
      const errorMessage =
        error.response?.status === HttpStatusCode.InternalServerError
          ? "Error fetching employee data"
          : error.response?.data?.message ||
            error.message ||
            "An unknown error occurred while fetching employee data.";
      dispatch(
        enqueueSnackbarMessage({
          message: errorMessage,
          type: "error",
        }),
      );
      return rejectWithValue(errorMessage);
    }
  },
  { condition: hubFetchCondition("employeesState") },
);

const employeeHubSlice = createSlice({
  name: "employeeHub",
  initialState,
  reducers: {},
  extraReducers: (builder) => {
    builder
      .addCase(fetchInternHubData.pending, (state) => {
        state.state = State.loading;
        state.errorMessage = null;
      })
      .addCase(fetchInternHubData.fulfilled, (state, action) => {
        state.state = State.success;
        state.interns = action.payload.interns;
      })
      .addCase(fetchInternHubData.rejected, (state, action) => {
        state.state = State.failed;
        state.errorMessage = (action.payload as string) || "Failed to load intern data";
      })
      .addCase(fetchEmployeeHubData.pending, (state) => {
        state.employeesState = State.loading;
        state.employeesErrorMessage = null;
      })
      .addCase(fetchEmployeeHubData.fulfilled, (state, action) => {
        state.employeesState = State.success;
        state.employeesErrorMessage = null;
        state.employeesIsLive = true;
        state.employees = action.payload.employees;
        state.leavers = action.payload.leavers;
      })
      .addCase(fetchEmployeeHubData.rejected, (state, action) => {
        // Data from an earlier successful load is no longer current, so it is
        // marked as not live and the Permanent page shows its Retry banner.
        state.employeesState = State.failed;
        state.employeesIsLive = false;
        state.employeesErrorMessage = (action.payload as string) || "Failed to load employee data";
      });
  },
});

export default employeeHubSlice.reducer;

export const selectInternHubState = (state: RootState) => state.employeeHub.state;
export const selectInterns = (state: RootState) => state.employeeHub.interns;
export const selectEmployeeHubState = (state: RootState) => state.employeeHub.employeesState;
export const selectEmployeeHub = (state: RootState) => state.employeeHub.employees;
