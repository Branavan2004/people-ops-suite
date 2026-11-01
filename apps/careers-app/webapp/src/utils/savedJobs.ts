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

import type { Dispatch } from "@reduxjs/toolkit";

import { toggleSaveJob } from "@slices/careersSlice/careers";
import type { RootState } from "@slices/store";

// Saved job ids kept in the browser per candidate.
export const SAVED_JOBS_KEY_PREFIX = "careers-app-saved-jobs:";
export const MAX_SAVED_JOBS = 200;

// The candidate's saved job ids; empty when none or unreadable.
export function readSavedJobs(userId: string): string[] {
  try {
    const stored: unknown = JSON.parse(localStorage.getItem(SAVED_JOBS_KEY_PREFIX + userId) ?? "[]");
    return Array.isArray(stored)
      ? stored.filter((id): id is string => typeof id === "string").slice(0, MAX_SAVED_JOBS)
      : [];
  } catch {
    return [];
  }
}

// Stores the most recent saved job ids; ignores blocked storage.
export function writeSavedJobs(userId: string, jobIds: string[]): void {
  try {
    localStorage.setItem(SAVED_JOBS_KEY_PREFIX + userId, JSON.stringify(jobIds.slice(-MAX_SAVED_JOBS)));
  } catch {
    // Storage is blocked or full.
  }
}

// Toggles a job and stores the candidate's saved jobs.
export const toggleSavedJob = (jobId: string) => (dispatch: Dispatch, getState: () => RootState) => {
  dispatch(toggleSaveJob(jobId));
  const state = getState();
  const userId = state.auth.decodedIdToken?.sub;
  if (userId) writeSavedJobs(userId, state.careers.savedJobIds);
};
