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

import axios, { type AxiosResponse } from "axios";

import {
  Application,
  ApplicationInterview,
  CandidateProfile,
  DocumentRequirements,
  DocumentsStatus,
  EditableProfileFields,
  OfferAnswer,
  PersonalDetails,
} from "@/types/types";
import { AppConfig } from "@config/config";
import {
  OFFER_CONFLICT_ERROR,
  OFFER_EXPIRED_ERROR,
  OFFER_INVALID_ERROR,
  OFFER_NOT_FOUND_ERROR,
} from "@config/constant";

const REQUEST_TIMEOUT_MS = 15_000;

// The name of the error thrown when the backend refuses the access token.
export const SESSION_EXPIRED_ERROR = "SessionExpiredError";

// The bearer token and timeout every signed-in request carries.
const requestOptions = (accessToken: string) => ({
  headers: { Authorization: `Bearer ${accessToken}` },
  timeout: REQUEST_TIMEOUT_MS,
});

// Waits for a request and returns its data; a 401 becomes a session expired error so the app can ask for sign-in.
async function send<T>(request: Promise<AxiosResponse<T>>): Promise<T> {
  try {
    return (await request).data;
  } catch (error) {
    if (axios.isAxiosError(error) && error.response?.status === 401) {
      const expired = new Error("Your session has ended.");
      expired.name = SESSION_EXPIRED_ERROR;
      throw expired;
    }
    throw error;
  }
}

// Asks for a new access token. It is set by the sign-in code, which owns the session with the identity provider.
let renewAccessToken: (() => Promise<string>) | null = null;
export const setTokenRenewer = (renewer: (() => Promise<string>) | null) => {
  renewAccessToken = renewer;
};

// The renewal that is running, so requests that fail together share one: a refresh token can be used only once.
let renewing: Promise<string> | null = null;
const renewOnce = (): Promise<string> => {
  if (!renewAccessToken) return Promise.reject(new Error("The session cannot be renewed."));
  if (!renewing) {
    renewing = renewAccessToken().finally(() => {
      renewing = null;
    });
  }
  return renewing;
};

// Sends a request with the access token. A 401 means the token has run out, so a new one is asked for and the request
// is sent once more. The session has ended only when no new token can be had, or the new one is refused as well.
async function sendRenewing<T>(
  accessToken: string,
  request: (token: string) => Promise<AxiosResponse<T>>,
): Promise<T> {
  try {
    return await send(request(accessToken));
  } catch (error) {
    if (!(error instanceof Error) || error.name !== SESSION_EXPIRED_ERROR) throw error;
    let fresh: string;
    try {
      fresh = await renewOnce();
    } catch {
      throw error;
    }
    return send(request(fresh));
  }
}

const FORCED_SIGN_OUT_KEY = "careers.forcedSignOutAt";
const FORCED_SIGN_OUT_WINDOW_MS = 60_000;

// Remembers that the app just signed the candidate out because the backend refused the session, so a sign-in that
// goes wrong the same way is not repeated for ever.
export const noteForcedSignOut = () => {
  try {
    sessionStorage.setItem(FORCED_SIGN_OUT_KEY, String(Date.now()));
  } catch {
    // Without storage the guard is not available.
  }
};

// Whether the candidate was signed out that way a moment ago.
export const forcedSignOutRecently = (): boolean => {
  try {
    return (
      Date.now() - Number(sessionStorage.getItem(FORCED_SIGN_OUT_KEY)) < FORCED_SIGN_OUT_WINDOW_MS
    );
  } catch {
    return false;
  }
};

const SIGN_IN_STARTED_KEY = "careers.signInStarted";

// Remembers that a sign-in was started from this app, so that the page the candidate returns to can load both the
// applications and the profile once. A refresh of a page, with the session still alive, starts no sign-in.
export const noteSignInStarted = () => {
  try {
    sessionStorage.setItem(SIGN_IN_STARTED_KEY, "1");
  } catch {
    // Without storage only the open page's data is loaded after a sign-in.
  }
};

// Whether a sign-in was started since the last time this was asked. The answer is true once.
export const consumeSignInStarted = (): boolean => {
  try {
    const started = sessionStorage.getItem(SIGN_IN_STARTED_KEY) === "1";
    sessionStorage.removeItem(SIGN_IN_STARTED_KEY);
    return started;
  } catch {
    return false;
  }
};

export const clearForcedSignOut = () => {
  try {
    sessionStorage.removeItem(FORCED_SIGN_OUT_KEY);
  } catch {
    // Nothing was stored.
  }
};

// Whether the address carries an error from the identity provider (access denied, a locked account and so on). A
// sign-in started again at once would be refused the same way, so the candidate is asked first.
export const hasSignInError = (search: string): boolean => new URLSearchParams(search).has("error");

// The signed-in candidate's own profile.
export async function fetchProfile(accessToken: string): Promise<CandidateProfile> {
  return sendRenewing(accessToken, (token) =>
    axios.get<CandidateProfile>(`${AppConfig.serviceUrls.candidates}/me`, requestOptions(token)),
  );
}

// Saves the changes to the candidate's editable details.
export async function saveProfile(
  accessToken: string,
  changes: Partial<EditableProfileFields>,
): Promise<CandidateProfile> {
  return sendRenewing(accessToken, (token) =>
    axios.patch<CandidateProfile>(
      `${AppConfig.serviceUrls.candidates}/me`,
      changes,
      requestOptions(token),
    ),
  );
}

const refused = (name: string, message: string) => Object.assign(new Error(message), { name });

// Records the candidate's answer to an offer. A 400 (with the reason the backend gives), a 404, a 409 and a 410 each
// become an error of their own.
export async function respondToOffer(accessToken: string, applicationId: string, answer: OfferAnswer): Promise<void> {
  const body =
    answer.response === "accepted"
      ? { decision: "ACCEPTED" }
      : { decision: "DECLINED", declineReason: answer.reason, declineReasonAdditional: answer.comment || undefined };
  try {
    await sendRenewing(accessToken, (token) =>
      axios.post(
        `${AppConfig.serviceUrls.applications}/${encodeURIComponent(applicationId)}/offer/decision`,
        body,
        requestOptions(token),
      ),
    );
  } catch (error) {
    const status = axios.isAxiosError(error) ? error.response?.status : undefined;
    if (status === 400) {
      const reason = axios.isAxiosError(error) ? (error.response?.data as { message?: unknown })?.message : undefined;
      throw refused(OFFER_INVALID_ERROR, typeof reason === "string" && reason ? reason : "The answer was not accepted.");
    }
    if (status === 404) throw refused(OFFER_NOT_FOUND_ERROR, "There is no offer to answer.");
    if (status === 409) throw refused(OFFER_CONFLICT_ERROR, "The offer cannot be answered.");
    if (status === 410) throw refused(OFFER_EXPIRED_ERROR, "The offer has expired.");
    throw error;
  }
}

// The interviews of one of the candidate's applications, in the order they take place.
export async function fetchInterviews(
  accessToken: string,
  applicationId: string,
): Promise<ApplicationInterview[]> {
  return sendRenewing(accessToken, (token) =>
    axios.get<ApplicationInterview[]>(
      `${AppConfig.serviceUrls.applications}/${encodeURIComponent(applicationId)}/interviews`,
      requestOptions(token),
    ),
  );
}

// Whether the candidate has submitted the documents for one of their accepted offers, whether they can still change
// them, and what they saved.
export async function fetchDocumentsStatus(
  accessToken: string,
  applicationId: string,
): Promise<DocumentsStatus> {
  return sendRenewing(accessToken, (token) =>
    axios.get<DocumentsStatus>(
      `${AppConfig.serviceUrls.applications}/${encodeURIComponent(applicationId)}/documents`,
      requestOptions(token),
    ),
  );
}

// How long a submission waits for the reply.
const DOCUMENT_UPLOAD_TIMEOUT_MS = 120_000;

// The documents a candidate is asked for, and the limits every file must meet.
export async function fetchDocumentRequirements(
  accessToken: string,
): Promise<DocumentRequirements> {
  return sendRenewing(accessToken, (token) =>
    axios.get<DocumentRequirements>(
      `${AppConfig.serviceUrls.documents}/requirements`,
      requestOptions(token),
    ),
  );
}

// Sends the chosen files, one per requested document, with the details and the declaration.
export async function submitDocuments(
  accessToken: string,
  applicationId: string,
  files: Record<string, File>,
  details: PersonalDetails,
  changing = false,
): Promise<void> {
  const form = new FormData();
  form.append("declaration", "true");
  // The details go as one block.
  form.append("details", JSON.stringify(details));
  // Each file is sent under its document key, not its own name.
  Object.entries(files).forEach(([key, file]) => form.append(key, file, key));
  const url = `${AppConfig.serviceUrls.applications}/${encodeURIComponent(applicationId)}/documents`;
  // A first submission is a POST; a change is a PUT that carries only the replaced files.
  await sendRenewing(accessToken, (token) => {
    const options = { ...requestOptions(token), timeout: DOCUMENT_UPLOAD_TIMEOUT_MS };
    return changing ? axios.put(url, form, options) : axios.post(url, form, options);
  });
}

// The signed-in candidate's own applications.
export async function fetchApplications(accessToken: string): Promise<Application[]> {
  return sendRenewing(accessToken, (token) =>
    axios.get<Application[]>(AppConfig.serviceUrls.applications, requestOptions(token)),
  );
}
