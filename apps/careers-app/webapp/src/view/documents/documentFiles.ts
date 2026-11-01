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

import type { DocumentRequirement, DocumentRequirements } from "@/types/types";
import { SnackMessage } from "@config/constant";
import { SESSION_EXPIRED_ERROR } from "@utils/profileService";

const MEGABYTE = 1024 * 1024;

export const STEPS = ["Personal details", "Documents", "Photos", "Review & submit"];
export const DETAILS_STEP = 0;
export const DOCUMENTS_STEP = 1;
export const PHOTOS_STEP = 2;
export const REVIEW_STEP = 3;

export const formatSize = (bytes: number) => `${(bytes / MEGABYTE).toFixed(1)} MB`;

// A deadline, from its ISO 8601 text, as a date to read.
export const deadlineText = (iso: string) =>
  new Date(iso).toLocaleDateString(undefined, { day: "numeric", month: "long", year: "numeric" });

const extensionOf = (fileName: string) => fileName.split(".").pop()?.toLowerCase() ?? "";

// The file extensions a document accepts.
export const extensionsOf = (types: string[]) => types.flatMap((type) => (type === "jpg" ? ["jpg", "jpeg"] : [type]));

// The formats a document accepts, for the line under its name.
export const formatsText = (types: string[]) => (types.includes("pdf") ? "PDF" : "JPG or PNG");

// The kind of file a document needs, in a sentence.
const typesText = (types: string[]) => (types.includes("pdf") ? "a PDF file" : "a JPG or PNG image");

// The message for a picture that is not square or not big enough, or an empty text when it is fine.
export const squareProblem = async (file: File, side: number) => {
  try {
    const bitmap = await createImageBitmap(file);
    const { width, height } = bitmap;
    bitmap.close();
    return width === height && width >= side ? "" : `The picture must be square, at least ${side} x ${side} pixels.`;
  } catch {
    return "This picture could not be read.";
  }
};

// The record without the given key.
export function without<T>(record: Record<string, T>, key: string): Record<string, T> {
  return Object.fromEntries(Object.entries(record).filter(([name]) => name !== key));
}

// The message for a file that cannot be sent, or an empty text when the file is fine.
export const problemWith = (file: File, requirements: DocumentRequirements, document: DocumentRequirement) => {
  if (file.size === 0) return "This file is empty.";
  if (file.size > requirements.maxFileBytes) return `This file is larger than ${formatSize(requirements.maxFileBytes)}.`;
  if (extensionsOf(document.types).includes(extensionOf(file.name))) return "";
  return `Send ${typesText(document.types)}.`;
};

// How far a section has got: nothing chosen yet, a file that is ready, or a file that was refused.
export const STATUS_COLORS = { Complete: "success", Pending: "default", "Action needed": "error" } as const;

export const statusOf = (hasFile: boolean, problem: string | undefined): keyof typeof STATUS_COLORS =>
  problem ? "Action needed" : hasFile ? "Complete" : "Pending";

// Whether a request failed because the sign-in has ended, as opposed to being refused.
export const isSessionEnded = (error: unknown) => error instanceof Error && error.name === SESSION_EXPIRED_ERROR;

// The message for a submission that was refused, taken from the reply when the backend explains why.
export const submitFailureMessage = (error: unknown) => {
  if (isSessionEnded(error)) return SnackMessage.error.sessionEndedOnSubmit;
  const status = axios.isAxiosError(error) ? error.response?.status : undefined;
  if (status === 400 || status === 403 || status === 409) {
    const reason = axios.isAxiosError(error) ? (error.response?.data as { message?: unknown })?.message : undefined;
    if (typeof reason === "string") return reason;
  }
  if (status === 400) return SnackMessage.error.submitDocuments;
  if (status === 403 || status === 404) return SnackMessage.error.documentsNotAllowed;
  if (status === 409) return SnackMessage.error.documentsAlreadySent;
  if (status === 413) return SnackMessage.error.documentsTooLarge;
  if (status === 429) return SnackMessage.error.documentsTooManyAttempts;
  return SnackMessage.error.submitDocuments;
};
