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

import { PayloadAction, createAsyncThunk, createSlice, isRejected } from "@reduxjs/toolkit";

import {
  Application,
  ApplicationFeedback,
  ApplicationInterview,
  CandidateProfile,
  DocumentsStatus,
  EditableProfileFields,
  Job,
  OfferAnswer,
  OfferLetter,
  State,
} from "@/types/types";
import {
  fetchApplications as fetchApplicationsApi,
  fetchProfile as fetchProfileApi,
  respondToOffer as respondToOfferApi,
  saveProfile as saveProfileApi,
  SESSION_EXPIRED_ERROR,
  submitFeedback as submitFeedbackApi,
} from "@utils/profileService";
import {
  OrgStructure,
  VacancyDetail,
  fetchOrgStructure,
  fetchVacancies,
  fetchVacancyDetail,
} from "@utils/vacancyService";

// The fields of ApplicationExtras that are loaded from the backend.
export type ExtrasField = "offerLetter" | "interviews" | "documentsStatus";

// When a field was loaded, and the application's status and last change at that time.
export interface LoadedMark {
  at: number;
  version: string;
}

// What the application page loads for one application; a field is missing until it has been loaded once.
export interface ApplicationExtras {
  offerLetter?: OfferLetter | null;
  interviews?: ApplicationInterview[];
  // Undefined while loading, null when the check failed.
  documentsStatus?: DocumentsStatus | null;
  // Set when a load succeeded; a failed or cleared field has no mark and is loaded again.
  loaded?: Partial<Record<ExtrasField, LoadedMark>>;
}

// How long a loaded field is used without asking the backend again.
export const EXTRAS_FRESH_MS = 5 * 60_000;

// Changes when the application moves on, which makes what was loaded for it out of date.
export const extrasVersionOf = (application: Application): string =>
  `${application.status}|${application.updatedDate ?? ""}`;

// Whether a field was loaded for this version of the application, and recently enough to be used as it is.
export function isExtrasFresh(
  extras: ApplicationExtras | undefined,
  field: ExtrasField,
  version: string,
  now: number = Date.now(),
): boolean {
  const mark = extras?.loaded?.[field];
  return extras?.[field] !== undefined && mark !== undefined && mark.version === version && now - mark.at < EXTRAS_FRESH_MS;
}

interface CareersState {
  profile: CandidateProfile;
  profileState: State;
  jobs: Job[];
  jobsState: State;
  jobDetails: Record<string, VacancyDetail>;
  orgStructure: OrgStructure;
  orgStructureState: State;
  applications: Application[];
  applicationsState: State;
  // The interviews, offer letter and documents status of each opened application, by application id, kept so a page
  // that is opened again shows them at once.
  applicationExtras: Record<string, ApplicationExtras>;
  // Applications whose feedback request the candidate dismissed.
  dismissedFeedbackIds: string[];
  // True when the backend refused the access token.
  sessionExpired: boolean;
  // Counts the clears of the candidate's data.
  sessionGeneration: number;
  savedJobIds: string[];
}

// Error name of a request that ended after the candidate's data was cleared.
const STALE_SESSION_ERROR = "StaleSessionError";

const isSessionExpired = (error: { name?: string }) => error.name === SESSION_EXPIRED_ERROR;
const isStale = (error: { name?: string }) => error.name === STALE_SESSION_ERROR;

const emptyProfile: CandidateProfile = {
  firstName: "",
  lastName: "",
  gender: "",
  personalEmail: "",
  contactNo: "",
  address: null,
  university: null,
};

const initialState: CareersState = {
  profile: emptyProfile,
  profileState: State.idle,
  jobs: [],
  jobsState: State.idle,
  jobDetails: {},
  orgStructure: { locations: [], teams: [] },
  orgStructureState: State.idle,
  applications: [],
  applicationsState: State.idle,
  applicationExtras: {},
  dismissedFeedbackIds: [],
  sessionExpired: false,
  sessionGeneration: 0,
  // Loaded from the browser on sign-in.
  savedJobIds: [],
};

export const loadJobs = createAsyncThunk("careers/loadJobs", async (accessToken: string) => {
  return await fetchVacancies(accessToken);
});

export const loadOrgStructure = createAsyncThunk("careers/loadOrgStructure", async (accessToken: string) => {
  return await fetchOrgStructure(accessToken);
});

export const loadJobDetail = createAsyncThunk(
  "careers/loadJobDetail",
  async ({ accessToken, jobId }: { accessToken: string; jobId: string }) => {
    return await fetchVacancyDetail(jobId, accessToken);
  },
);

// Builds a signed-in request; a response arriving after the data was cleared is dropped as stale.
function userRequest<Arg, Result>(type: string, call: (arg: Arg) => Promise<Result>) {
  return createAsyncThunk<Result, Arg>(type, async (arg, { getState }) => {
    const generation = () => (getState() as { careers: CareersState }).careers.sessionGeneration;
    const started = generation();
    const stale = () => Object.assign(new Error("The candidate signed out."), { name: STALE_SESSION_ERROR });
    try {
      const result = await call(arg);
      if (generation() !== started) throw stale();
      return result;
    } catch (error) {
      throw generation() !== started ? stale() : error;
    }
  });
}

export const loadProfile = userRequest("careers/loadProfile", (accessToken: string) => fetchProfileApi(accessToken));

export const updateProfile = userRequest(
  "careers/updateProfile",
  ({ accessToken, changes }: { accessToken: string; changes: Partial<EditableProfileFields> }) =>
    saveProfileApi(accessToken, changes),
);

export const loadApplications = userRequest("careers/loadApplications", (accessToken: string) =>
  fetchApplicationsApi(accessToken),
);

export const sendFeedback = userRequest(
  "careers/sendFeedback",
  ({
    accessToken,
    applicationId,
    feedback,
  }: {
    accessToken: string;
    applicationId: string;
    feedback: ApplicationFeedback;
  }) => submitFeedbackApi(accessToken, applicationId, feedback),
);

export const respondToOffer = userRequest(
  "careers/respondToOffer",
  ({ accessToken, applicationId, answer }: { accessToken: string; applicationId: string; answer: OfferAnswer }) =>
    respondToOfferApi(accessToken, applicationId, answer),
);

const CareersSlice = createSlice({
  name: "careers",
  initialState,
  reducers: {
    // Replaces the saved jobs.
    setSavedJobs: (state, action: PayloadAction<string[]>) => {
      state.savedJobIds = action.payload;
    },
    // Keeps what was loaded for an application. A reply that arrives after the candidate's data was cleared, which
    // the generation tells, is dropped.
    setApplicationExtras: (
      state,
      action: PayloadAction<{ id: string; generation: number; extras: ApplicationExtras }>,
    ) => {
      const { id, generation, extras } = action.payload;
      if (generation !== state.sessionGeneration) return;
      const { loaded, ...fields } = extras;
      const existing = state.applicationExtras[id];
      state.applicationExtras[id] = {
        ...existing,
        ...fields,
        // The marks of other fields stay.
        ...(loaded && { loaded: { ...existing?.loaded, ...loaded } }),
      };
    },
    toggleSaveJob: (state, action: PayloadAction<string>) => {
      const idx = state.savedJobIds.indexOf(action.payload);
      if (idx >= 0) {
        state.savedJobIds.splice(idx, 1);
      } else {
        state.savedJobIds.push(action.payload);
      }
    },
    // Marks the jobs loads that never started as failed.
    loadFailed: (state) => {
      if (state.jobsState === State.idle) state.jobsState = State.failed;
      if (state.orgStructureState === State.idle) state.orgStructureState = State.failed;
    },
    // Puts failed jobs loads back to idle so they load again.
    retryLoad: (state) => {
      if (state.jobsState === State.failed) state.jobsState = State.idle;
      if (state.orgStructureState === State.failed) state.orgStructureState = State.idle;
    },
    // Marks the profile load as failed.
    profileFailed: (state) => {
      state.profileState = State.failed;
    },
    // Marks the applications load as failed.
    applicationsFailed: (state) => {
      state.applicationsState = State.failed;
    },
    // Puts a failed applications load back to idle so it loads again.
    retryApplications: (state) => {
      if (state.applicationsState === State.failed) state.applicationsState = State.idle;
    },
    // Marks the loaded applications as out of date, so they load again.
    refreshApplications: (state) => {
      if (state.applicationsState === State.success) state.applicationsState = State.idle;
    },
    // Remembers that the candidate dismissed the feedback request for an application.
    dismissFeedback: (state, action: PayloadAction<string>) => {
      if (!state.dismissedFeedbackIds.includes(action.payload)) state.dismissedFeedbackIds.push(action.payload);
    },
    // Clears the signed-in candidate's data.
    clearUserData: (state) => {
      state.profile = emptyProfile;
      state.profileState = State.idle;
      state.applications = [];
      state.applicationsState = State.idle;
      state.applicationExtras = {};
      state.dismissedFeedbackIds = [];
      state.sessionExpired = false;
      state.sessionGeneration += 1;
      state.savedJobIds = [];
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(loadJobs.pending, (state) => {
        state.jobsState = State.loading;
      })
      .addCase(loadJobs.fulfilled, (state, action) => {
        state.jobs = action.payload;
        state.jobsState = State.success;
      })
      .addCase(loadJobs.rejected, (state) => {
        state.jobsState = State.failed;
      })
      .addCase(loadOrgStructure.pending, (state) => {
        state.orgStructureState = State.loading;
      })
      .addCase(loadOrgStructure.fulfilled, (state, action) => {
        state.orgStructure = action.payload;
        state.orgStructureState = State.success;
      })
      .addCase(loadOrgStructure.rejected, (state) => {
        state.orgStructureState = State.failed;
        state.orgStructure = { locations: [], teams: [] };
      })
      .addCase(loadJobDetail.fulfilled, (state, action) => {
        state.jobDetails[action.payload.id] = action.payload;
      })
      .addCase(loadProfile.pending, (state) => {
        state.profileState = State.loading;
      })
      .addCase(loadProfile.fulfilled, (state, action) => {
        state.profile = action.payload;
        state.profileState = State.success;
      })
      .addCase(loadProfile.rejected, (state, action) => {
        if (!isStale(action.error)) state.profileState = State.failed;
      })
      .addCase(updateProfile.fulfilled, (state, action) => {
        state.profile = action.payload;
      })
      .addCase(loadApplications.pending, (state) => {
        state.applicationsState = State.loading;
      })
      .addCase(loadApplications.fulfilled, (state, action) => {
        state.applications = action.payload;
        state.applicationsState = State.success;
      })
      .addCase(loadApplications.rejected, (state, action) => {
        if (!isStale(action.error)) state.applicationsState = State.failed;
      })
      .addCase(sendFeedback.fulfilled, (state, action) => {
        const application = state.applications.find((a) => a.id === action.meta.arg.applicationId);
        if (application) application.feedbackSubmitted = true;
      })
      .addCase(respondToOffer.fulfilled, (state, action) => {
        const index = state.applications.findIndex((a) => a.id === action.payload.id);
        if (index >= 0) state.applications[index] = action.payload;
      })
      // A 401 on any signed-in request ends the session.
      .addMatcher(
        isRejected(loadProfile, updateProfile, loadApplications, sendFeedback, respondToOffer),
        (state, action) => {
          if (isSessionExpired(action.error)) state.sessionExpired = true;
        },
      );
  },
});

export const {
  setApplicationExtras,
  setSavedJobs,
  toggleSaveJob,
  loadFailed,
  retryLoad,
  profileFailed,
  applicationsFailed,
  retryApplications,
  refreshApplications,
  dismissFeedback,
  clearUserData,
} = CareersSlice.actions;

export default CareersSlice.reducer;
