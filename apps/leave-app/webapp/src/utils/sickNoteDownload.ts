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

export const SICK_NOTE_ERROR = "The sick note could not be downloaded.";

const SICK_NOTE_EXTENSIONS: Record<string, string> = {
  "application/pdf": ".pdf",
  "image/jpeg": ".jpg",
  "image/png": ".png",
};

// File extension (with dot) for a sick note content type; empty when unknown. Media types are
// case-insensitive, so the lookup is too, and only the map's own keys count, never inherited ones
// such as "constructor".
export const sickNoteExtension = (contentType: string): string => {
  const key = contentType.toLowerCase();
  return Object.hasOwn(SICK_NOTE_EXTENSIONS, key) ? SICK_NOTE_EXTENSIONS[key] : "";
};

// Pulls `message` out of a JSON error body; falls back to the generic message.
export const messageFromErrorText = (text: string): string => {
  try {
    const body = JSON.parse(text) as { message?: unknown };
    if (typeof body?.message === "string" && body.message) return body.message;
  } catch {
    // Fall through to the generic message.
  }
  return SICK_NOTE_ERROR;
};

// With responseType "blob", axios delivers error bodies as a Blob, so read it to get the message.
export async function sickNoteErrorMessage(err: unknown): Promise<string> {
  if (axios.isAxiosError(err) && err.response?.data instanceof Blob) {
    return messageFromErrorText(await err.response.data.text());
  }
  return SICK_NOTE_ERROR;
}

// How long the temporary object URL outlives the click, so the browser can start the download first.
export const OBJECT_URL_REVOKE_DELAY_MS = 10_000;

// Saves a sick note through a temporary object URL (revoked shortly afterwards). Nothing is retained.
export function saveSickNoteBlob(blob: Blob, leaveId: number): void {
  const url = URL.createObjectURL(blob);
  try {
    const link = document.createElement("a");
    link.href = url;
    link.download = `sick-note-${leaveId}${sickNoteExtension(blob.type)}`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  } finally {
    // Revoking straight after click() can cancel the download in Safari and some Firefox versions.
    setTimeout(() => URL.revokeObjectURL(url), OBJECT_URL_REVOKE_DELAY_MS);
  }
}
