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
  ApplicationFeedback,
  ApplicationInterview,
  CandidateProfile,
  DocumentRequirements,
  DocumentsStatus,
  EditableProfileFields,
  OfferAnswer,
  OfferLetter,
  PersonalDetails,
} from "@/types/types";
import { AppConfig, UseMockProfile } from "@config/config";
import { OFFER_CONFLICT_ERROR, OFFER_EXPIRED_ERROR } from "@config/constant";
import * as mockProfile from "@utils/mockProfile";

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

// The signed-in candidate's own profile.
export async function fetchProfile(accessToken: string): Promise<CandidateProfile> {
  if (UseMockProfile) return mockProfile.fetchProfile();
  return send(axios.get<CandidateProfile>(`${AppConfig.serviceUrls.candidates}/me`, requestOptions(accessToken)));
}

// Saves the changes to the candidate's editable details.
export async function saveProfile(
  accessToken: string,
  changes: Partial<EditableProfileFields>,
): Promise<CandidateProfile> {
  if (UseMockProfile) return mockProfile.saveProfile(changes);
  return send(
    axios.patch<CandidateProfile>(`${AppConfig.serviceUrls.candidates}/me`, changes, requestOptions(accessToken)),
  );
}

// Sends the candidate's feedback about one of their applications.
export async function submitFeedback(
  accessToken: string,
  applicationId: string,
  feedback: ApplicationFeedback,
): Promise<void> {
  if (UseMockProfile) return mockProfile.submitFeedback(applicationId);
  await send(
    axios.post(
      `${AppConfig.serviceUrls.applications}/${encodeURIComponent(applicationId)}/feedback`,
      feedback,
      requestOptions(accessToken),
    ),
  );
}

const refused = (name: string, message: string) => Object.assign(new Error(message), { name });

// Records the candidate's answer to an offer and returns the updated application; a 409 or a 410 becomes an error of
// its own.
export async function respondToOffer(
  accessToken: string,
  applicationId: string,
  answer: OfferAnswer,
): Promise<Application> {
  if (UseMockProfile) return mockProfile.respondToOffer(applicationId, answer);
  try {
    return await send(
      axios.post<Application>(
        `${AppConfig.serviceUrls.applications}/${encodeURIComponent(applicationId)}/offer-response`,
        answer,
        requestOptions(accessToken),
      ),
    );
  } catch (error) {
    const status = axios.isAxiosError(error) ? error.response?.status : undefined;
    if (status === 409) throw refused(OFFER_CONFLICT_ERROR, "The offer cannot be answered.");
    if (status === 410) throw refused(OFFER_EXPIRED_ERROR, "The offer has expired.");
    throw error;
  }
}

// The offer letter sent for one of the candidate's applications, or null when none was found.
export async function fetchOfferLetter(accessToken: string, applicationId: string): Promise<OfferLetter | null> {
  if (UseMockProfile) return mockProfile.fetchOfferLetter();
  try {
    return await send(
      axios.get<OfferLetter>(
        `${AppConfig.serviceUrls.applications}/${encodeURIComponent(applicationId)}/offer-letter`,
        requestOptions(accessToken),
      ),
    );
  } catch (error) {
    if (axios.isAxiosError(error) && error.response?.status === 404) return null;
    throw error;
  }
}

// The interviews of one of the candidate's applications, in the order they take place.
export async function fetchInterviews(accessToken: string, applicationId: string): Promise<ApplicationInterview[]> {
  if (UseMockProfile) return mockProfile.fetchInterviews(applicationId);
  return send(
    axios.get<ApplicationInterview[]>(
      `${AppConfig.serviceUrls.applications}/${encodeURIComponent(applicationId)}/interviews`,
      requestOptions(accessToken),
    ),
  );
}

// Whether the candidate has submitted the documents for one of their accepted offers, whether they can still change
// them, and what they saved.
export async function fetchDocumentsStatus(accessToken: string, applicationId: string): Promise<DocumentsStatus> {
  if (UseMockProfile) return mockProfile.fetchDocumentsStatus(applicationId);
  return send(
    axios.get<DocumentsStatus>(
      `${AppConfig.serviceUrls.applications}/${encodeURIComponent(applicationId)}/documents`,
      requestOptions(accessToken),
    ),
  );
}

// How long a submission waits for the reply.
const DOCUMENT_UPLOAD_TIMEOUT_MS = 120_000;

// The documents a candidate is asked for, and the limits every file must meet.
export async function fetchDocumentRequirements(accessToken: string): Promise<DocumentRequirements> {
  if (UseMockProfile) return mockProfile.fetchDocumentRequirements();
  return send(
    axios.get<DocumentRequirements>(`${AppConfig.serviceUrls.documents}/requirements`, requestOptions(accessToken)),
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
  if (UseMockProfile) return mockProfile.submitDocuments(applicationId, files, details);
  const form = new FormData();
  form.append("declaration", "true");
  // The details go as one block.
  form.append("details", JSON.stringify(details));
  // Each file is sent under its document key, not its own name.
  Object.entries(files).forEach(([key, file]) => form.append(key, file, key));
  const url = `${AppConfig.serviceUrls.applications}/${encodeURIComponent(applicationId)}/documents`;
  const options = { ...requestOptions(accessToken), timeout: DOCUMENT_UPLOAD_TIMEOUT_MS };
  // A first submission is a POST; a change is a PUT that carries only the replaced files.
  await send(changing ? axios.put(url, form, options) : axios.post(url, form, options));
}

// Lists an application the candidate just made when mock data is on.
export function trackSubmittedApplication(jobId: string, jobTitle: string, department: string): void {
  if (UseMockProfile) mockProfile.addApplication(jobId, jobTitle, department);
}

// The signed-in candidate's own applications.
export async function fetchApplications(accessToken: string): Promise<Application[]> {
  if (UseMockProfile) return mockProfile.fetchApplications();
  return send(axios.get<Application[]>(AppConfig.serviceUrls.applications, requestOptions(accessToken)));
}
