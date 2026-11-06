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

import { configureStore } from "@reduxjs/toolkit";
import { beforeEach, describe, expect, it, vi } from "vitest";

import { type Application, type CandidateProfile, State } from "@/types/types";
import { ApplicationStatus } from "@config/constant";
import reducer, {
  clearUserData,
  loadApplications,
  loadProfile,
  respondToOffer,
  updateProfile,
} from "@slices/careersSlice/careers";
import * as api from "@utils/profileService";

// The config reads window.config when it loads, which does not exist in these tests.
vi.mock("@config/config", () => ({
  AppConfig: { serviceUrls: { candidates: "", applications: "" } },
  ServiceBaseUrl: "",
}));

vi.mock("@utils/profileService", () => ({
  SESSION_EXPIRED_ERROR: "SessionExpiredError",
  fetchProfile: vi.fn(),
  saveProfile: vi.fn(),
  fetchApplications: vi.fn(),
  respondToOffer: vi.fn(),
}));

const previousProfile: CandidateProfile = {
  firstName: "Previous",
  lastName: "Candidate",
  gender: "",
  personalEmail: "previous",
  contactNo: "",
  address: null,
  university: null,
};

const previousApplication: Application = {
  id: "a1",
  jobId: "1",
  jobTitle: "Engineer",
  appliedDate: "2026-09-01",
  status: ApplicationStatus.Offer,
};

// A promise the test settles by hand, to finish a request at a moment of its choosing.
const deferred = <T>() => {
  let resolve!: (value: T) => void;
  let reject!: (error: Error) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
};

const newStore = () => configureStore({ reducer: { careers: reducer } });

describe("requests that finish after the candidate's data is cleared", () => {
  beforeEach(() => vi.clearAllMocks());

  it("keeps a profile load that finishes in time", async () => {
    const request = deferred<CandidateProfile>();
    vi.mocked(api.fetchProfile).mockReturnValue(request.promise);
    const store = newStore();

    const done = store.dispatch(loadProfile("token"));
    request.resolve(previousProfile);
    await done;

    expect(store.getState().careers.profile.firstName).toBe("Previous");
    expect(store.getState().careers.profileState).toBe(State.success);
  });

  it("drops a profile load that finishes after the data was cleared", async () => {
    const request = deferred<CandidateProfile>();
    vi.mocked(api.fetchProfile).mockReturnValue(request.promise);
    const store = newStore();

    const done = store.dispatch(loadProfile("token"));
    store.dispatch(clearUserData());
    request.resolve(previousProfile);
    await done;

    expect(store.getState().careers.profile.firstName).toBe("");
    expect(store.getState().careers.profileState).toBe(State.idle);
  });

  it("drops an applications load that finishes after the data was cleared", async () => {
    const request = deferred<Application[]>();
    vi.mocked(api.fetchApplications).mockReturnValue(request.promise);
    const store = newStore();

    const done = store.dispatch(loadApplications("token"));
    store.dispatch(clearUserData());
    request.resolve([previousApplication]);
    await done;

    expect(store.getState().careers.applications).toEqual([]);
    expect(store.getState().careers.applicationsState).toBe(State.idle);
  });

  it("drops a profile save that finishes after the data was cleared", async () => {
    const request = deferred<CandidateProfile>();
    vi.mocked(api.saveProfile).mockReturnValue(request.promise);
    const store = newStore();

    const done = store.dispatch(updateProfile({ accessToken: "token", changes: { firstName: "Previous" } }));
    store.dispatch(clearUserData());
    request.resolve(previousProfile);
    await done;

    expect(store.getState().careers.profile.firstName).toBe("");
  });

  it("does not ask to sign in again when an offer answer of a cleared session is refused", async () => {
    const request = deferred<void>();
    vi.mocked(api.respondToOffer).mockReturnValue(request.promise);
    const store = newStore();

    const done = store.dispatch(
      respondToOffer({ accessToken: "token", applicationId: "a1", answer: { response: "accepted" } }),
    );
    store.dispatch(clearUserData());
    request.reject(Object.assign(new Error("Your session has ended."), { name: "SessionExpiredError" }));
    await done;

    expect(store.getState().careers.sessionExpired).toBe(false);
  });

  it("does not mark the page failed or ask to sign in again when a cleared request fails", async () => {
    const request = deferred<CandidateProfile>();
    vi.mocked(api.fetchProfile).mockReturnValue(request.promise);
    const store = newStore();

    const done = store.dispatch(loadProfile("token"));
    store.dispatch(clearUserData());
    request.reject(Object.assign(new Error("Your session has ended."), { name: "SessionExpiredError" }));
    await done;

    expect(store.getState().careers.profileState).toBe(State.idle);
    expect(store.getState().careers.sessionExpired).toBe(false);
  });

  it("still asks to sign in again when a request in the current session is refused", async () => {
    vi.mocked(api.fetchProfile).mockRejectedValue(
      Object.assign(new Error("Your session has ended."), { name: "SessionExpiredError" }),
    );
    const store = newStore();

    await store.dispatch(loadProfile("token"));

    expect(store.getState().careers.profileState).toBe(State.failed);
    expect(store.getState().careers.sessionExpired).toBe(true);
  });
});
