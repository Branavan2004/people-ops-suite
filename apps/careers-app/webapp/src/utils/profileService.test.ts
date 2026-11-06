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
import axios from "axios";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  SESSION_EXPIRED_ERROR,
  clearForcedSignOut,
  fetchApplications,
  forcedSignOutRecently,
  hasSignInError,
  noteForcedSignOut,
  respondToOffer,
  setTokenRenewer,
} from "@utils/profileService";

// The service reads the app's config when it loads, which needs a browser window.
vi.mock("@config/config", () => ({
  AppConfig: {
    serviceUrls: {
      candidates: "/candidates",
      applications: "/applications",
      documents: "/documents",
    },
  },
}));
vi.mock("axios", () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    isAxiosError: (error: unknown) => Boolean((error as { isAxiosError?: boolean }).isAxiosError),
  },
}));

const get = vi.mocked(axios.get);
const post = vi.mocked(axios.post);
const refused = () =>
  Object.assign(new Error("401"), { isAxiosError: true, response: { status: 401 } });
const serverError = () =>
  Object.assign(new Error("500"), { isAxiosError: true, response: { status: 500 } });
const bearer = (token: string) =>
  expect.objectContaining({ headers: { Authorization: `Bearer ${token}` } });

describe("a request whose token was refused", () => {
  beforeEach(() => {
    get.mockReset();
  });

  afterEach(() => {
    setTokenRenewer(null);
  });

  it("is sent again with a new token, and the candidate stays signed in", async () => {
    const renew = vi.fn().mockResolvedValue("fresh");
    setTokenRenewer(renew);
    get.mockRejectedValueOnce(refused()).mockResolvedValueOnce({ data: [{ id: "1" }] });

    await expect(fetchApplications("old")).resolves.toEqual([{ id: "1" }]);
    expect(renew).toHaveBeenCalledTimes(1);
    expect(get).toHaveBeenNthCalledWith(1, "/applications", bearer("old"));
    expect(get).toHaveBeenNthCalledWith(2, "/applications", bearer("fresh"));
  });

  it("ends the session when no new token can be had, without sending the request again", async () => {
    setTokenRenewer(vi.fn().mockRejectedValue(new Error("no session")));
    get.mockRejectedValue(refused());

    await expect(fetchApplications("old")).rejects.toMatchObject({ name: SESSION_EXPIRED_ERROR });
    expect(get).toHaveBeenCalledTimes(1);
  });

  it("ends the session when the new token is refused as well, after one renewal", async () => {
    const renew = vi.fn().mockResolvedValue("fresh");
    setTokenRenewer(renew);
    get.mockRejectedValue(refused());

    await expect(fetchApplications("old")).rejects.toMatchObject({ name: SESSION_EXPIRED_ERROR });
    expect(renew).toHaveBeenCalledTimes(1);
    expect(get).toHaveBeenCalledTimes(2);
  });

  it("ends the session when there is no way to renew", async () => {
    get.mockRejectedValue(refused());

    await expect(fetchApplications("old")).rejects.toMatchObject({ name: SESSION_EXPIRED_ERROR });
    expect(get).toHaveBeenCalledTimes(1);
  });

  it("shares one renewal between requests that fail together", async () => {
    let finish: (token: string) => void = () => undefined;
    const renew = vi.fn(() => new Promise<string>((resolve) => (finish = resolve)));
    setTokenRenewer(renew);
    get.mockImplementation((_url, options) =>
      (options?.headers as { Authorization: string }).Authorization === "Bearer old"
        ? Promise.reject(refused())
        : Promise.resolve({ data: [] }),
    );

    const both = Promise.all([fetchApplications("old"), fetchApplications("old")]);
    await vi.waitFor(() => expect(renew).toHaveBeenCalledTimes(1));
    finish("fresh");
    await expect(both).resolves.toEqual([[], []]);
    expect(renew).toHaveBeenCalledTimes(1);
  });

  it("does not renew for an error that is not a refused token", async () => {
    const renew = vi.fn();
    setTokenRenewer(renew);
    get.mockRejectedValue(serverError());

    await expect(fetchApplications("old")).rejects.toThrow("500");
    expect(renew).not.toHaveBeenCalled();
  });
});

describe("the note of a forced sign-out", () => {
  const stored = new Map<string, string>();

  beforeEach(() => {
    stored.clear();
    vi.stubGlobal("sessionStorage", {
      getItem: (key: string) => stored.get(key) ?? null,
      setItem: (key: string, value: string) => stored.set(key, value),
      removeItem: (key: string) => stored.delete(key),
    });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.useRealTimers();
  });

  it("is not there until a sign-out is noted", () => {
    expect(forcedSignOutRecently()).toBe(false);
  });

  it("is recent right after, and only for a minute", () => {
    vi.useFakeTimers();
    noteForcedSignOut();
    expect(forcedSignOutRecently()).toBe(true);
    vi.advanceTimersByTime(59_000);
    expect(forcedSignOutRecently()).toBe(true);
    vi.advanceTimersByTime(2_000);
    expect(forcedSignOutRecently()).toBe(false);
  });

  it("can be cleared", () => {
    noteForcedSignOut();
    clearForcedSignOut();
    expect(forcedSignOutRecently()).toBe(false);
  });

  it("counts as not recent when the browser blocks its storage", () => {
    vi.stubGlobal("sessionStorage", {
      getItem: () => {
        throw new Error("blocked");
      },
    });
    expect(forcedSignOutRecently()).toBe(false);
  });
});

describe("an error from the identity provider on the address", () => {
  it("is found whatever else the address carries", () => {
    expect(hasSignInError("?error=access_denied")).toBe(true);
    expect(hasSignInError("?email=a%40b.c&error=login_required&state=x")).toBe(true);
  });

  it("is not there on a normal address or a normal sign-in return", () => {
    expect(hasSignInError("")).toBe(false);
    expect(hasSignInError("?email=a%40b.c")).toBe(false);
    expect(hasSignInError("?code=abc&state=xyz")).toBe(false);
  });
});

describe("an answer to an offer", () => {
  const failure = (status: number, data?: unknown) =>
    Object.assign(new Error(String(status)), { isAxiosError: true, response: { status, data } });

  beforeEach(() => {
    post.mockReset();
    post.mockResolvedValue({ data: undefined });
  });

  it("sends an acceptance to the decision address", async () => {
    await respondToOffer("token", "a 1", { response: "accepted" });
    expect(post).toHaveBeenCalledWith(
      "/applications/a%201/offer/decision",
      { decision: "ACCEPTED" },
      bearer("token"),
    );
  });

  it("sends a decline with its reason and the additional reason", async () => {
    await respondToOffer("token", "a1", {
      response: "declined",
      reason: "Compensation",
      comment: "Too low",
    });
    expect(post).toHaveBeenCalledWith(
      "/applications/a1/offer/decision",
      { decision: "DECLINED", declineReason: "Compensation", declineReasonAdditional: "Too low" },
      bearer("token"),
    );
  });

  it("leaves out an empty additional reason", async () => {
    await respondToOffer("token", "a1", { response: "declined", reason: "Other", comment: "" });
    expect(post.mock.calls[0][1]).toEqual({
      decision: "DECLINED",
      declineReason: "Other",
      declineReasonAdditional: undefined,
    });
  });

  it.each([
    [404, "OfferNotFoundError"],
    [409, "OfferConflictError"],
    [410, "OfferExpiredError"],
  ])("turns a %i into %s", async (status, name) => {
    post.mockRejectedValue(failure(status));
    await expect(respondToOffer("token", "a1", { response: "accepted" })).rejects.toMatchObject({
      name,
    });
  });

  it("keeps the message the backend gives for a 400", async () => {
    post.mockRejectedValue(failure(400, { message: "Choose a reason for declining." }));
    await expect(respondToOffer("token", "a1", { response: "accepted" })).rejects.toMatchObject({
      name: "OfferInvalidError",
      message: "Choose a reason for declining.",
    });
  });
});
