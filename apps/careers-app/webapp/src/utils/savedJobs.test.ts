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

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import { toggleSaveJob } from "@slices/careersSlice/careers";
import type { RootState } from "@slices/store";
import {
  MAX_SAVED_JOBS,
  SAVED_JOBS_KEY_PREFIX,
  readSavedJobs,
  toggleSavedJob,
  writeSavedJobs,
} from "@utils/savedJobs";

// The slice reads the app's config when it loads, which needs a browser window.
vi.mock("@config/config", () => ({
  AppConfig: { serviceUrls: { candidates: "", jobs: "", applications: "", documents: "" } },
  ServiceBaseUrl: "",
  UseMockProfile: false,
}));

// A stand-in for the browser's storage.
const storage = new Map<string, string>();

beforeEach(() => {
  storage.clear();
  vi.stubGlobal("localStorage", {
    getItem: (key: string) => storage.get(key) ?? null,
    setItem: (key: string, value: string) => void storage.set(key, value),
  });
});

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("readSavedJobs", () => {
  it("has no jobs for a candidate who saved none", () => {
    expect(readSavedJobs("u1")).toEqual([]);
  });

  it("gives back the jobs saved for that candidate only", () => {
    storage.set(`${SAVED_JOBS_KEY_PREFIX}u1`, JSON.stringify(["1", "2"]));
    storage.set(`${SAVED_JOBS_KEY_PREFIX}u2`, JSON.stringify(["9"]));
    expect(readSavedJobs("u1")).toEqual(["1", "2"]);
    expect(readSavedJobs("u2")).toEqual(["9"]);
  });

  it("ignores stored data that cannot be read", () => {
    storage.set(`${SAVED_JOBS_KEY_PREFIX}u1`, "{not json");
    expect(readSavedJobs("u1")).toEqual([]);
    storage.set(`${SAVED_JOBS_KEY_PREFIX}u1`, JSON.stringify({ id: "1" }));
    expect(readSavedJobs("u1")).toEqual([]);
  });

  it("keeps only the ids that are text, and no more than the limit", () => {
    storage.set(`${SAVED_JOBS_KEY_PREFIX}u1`, JSON.stringify(["1", 2, null, "3"]));
    expect(readSavedJobs("u1")).toEqual(["1", "3"]);
    const many = Array.from({ length: MAX_SAVED_JOBS + 20 }, (_, i) => String(i));
    storage.set(`${SAVED_JOBS_KEY_PREFIX}u1`, JSON.stringify(many));
    expect(readSavedJobs("u1")).toHaveLength(MAX_SAVED_JOBS);
  });

  it("has no jobs when the browser blocks its storage", () => {
    vi.stubGlobal("localStorage", {
      getItem: () => {
        throw new Error("blocked");
      },
    });
    expect(readSavedJobs("u1")).toEqual([]);
  });
});

describe("writeSavedJobs", () => {
  it("keeps the most recent jobs when there are more than the limit", () => {
    const many = Array.from({ length: MAX_SAVED_JOBS + 5 }, (_, i) => String(i));
    writeSavedJobs("u1", many);
    const kept = readSavedJobs("u1");
    expect(kept).toHaveLength(MAX_SAVED_JOBS);
    expect(kept[0]).toBe("5");
  });

  it("does not fail when the browser blocks its storage", () => {
    vi.stubGlobal("localStorage", {
      setItem: () => {
        throw new Error("full");
      },
    });
    expect(() => writeSavedJobs("u1", ["1"])).not.toThrow();
  });
});

describe("toggleSavedJob", () => {
  const stateOf = (userId: string | undefined, savedJobIds: string[]) =>
    ({
      auth: { decodedIdToken: userId ? { sub: userId } : null },
      careers: { savedJobIds },
    }) as unknown as RootState;

  it("toggles the job and keeps the resulting list for the signed-in candidate", () => {
    const dispatch = vi.fn();
    toggleSavedJob("7")(dispatch, () => stateOf("u1", ["3", "7"]));
    expect(dispatch).toHaveBeenCalledWith(toggleSaveJob("7"));
    expect(readSavedJobs("u1")).toEqual(["3", "7"]);
  });

  it("keeps nothing when nobody is signed in", () => {
    const dispatch = vi.fn();
    toggleSavedJob("7")(dispatch, () => stateOf(undefined, ["7"]));
    expect(dispatch).toHaveBeenCalledWith(toggleSaveJob("7"));
    expect(storage.size).toBe(0);
  });
});
