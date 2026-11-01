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

import { useAppDispatch, useAppSelector } from "@slices/store";
import { fetchInternHubData, fetchEmployeeHubData } from "@slices/employeeHubSlice/employeeHub";
import { State } from "@/types/types";

// Read-only: this hub only reads from the backend (GET /intern-profiles and
// GET /employee-hub/employees) - there's no write path in the UI, so no
// create/update/delete here. The initial fetch is
// dispatched once by useEmployeeHubBootstrap on first mount; this hook just reads the
// resulting state, so calling it from multiple pages/components doesn't
// cause refetch loops.
export const useEmployeeHub = () => {
  const dispatch = useAppDispatch();
  const state = useAppSelector((s) => s.employeeHub);

  return {
    interns: state.interns,
    loading: state.state === State.loading || state.state === State.idle,
    errorMessage: state.errorMessage,
    refetch: () => dispatch(fetchInternHubData({ force: true })),
    // Employee roster for the Dashboard's "Permanent Employees" tab, loaded
    // from /employee-hub/employees - kept separate from people-app's `employee` slice.
    employees: state.employees,
    leavers: state.leavers,
    employeesLoading: state.employeesState === State.loading || state.employeesState === State.idle,
    employeesErrorMessage: state.employeesErrorMessage,
    // True once the /employee-hub/employees fetch has succeeded. False means
    // the fetch hasn't finished, or the latest one failed.
    employeesIsLive: state.employeesIsLive,
    refetchEmployees: () => dispatch(fetchEmployeeHubData({ force: true })),
  };
};
