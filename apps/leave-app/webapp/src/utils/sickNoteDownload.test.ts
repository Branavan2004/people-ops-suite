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

import { afterEach, describe, expect, it, vi } from "vitest";

import {
  OBJECT_URL_REVOKE_DELAY_MS,
  SICK_NOTE_ERROR,
  messageFromErrorText,
  saveSickNoteBlob,
  sickNoteExtension,
} from "@utils/sickNoteDownload";

describe("sickNoteExtension", () => {
  it("maps the allowed content types", () => {
    expect(sickNoteExtension("application/pdf")).toBe(".pdf");
    expect(sickNoteExtension("image/jpeg")).toBe(".jpg");
    expect(sickNoteExtension("image/png")).toBe(".png");
  });
  it("ignores the case of the content type", () => {
    expect(sickNoteExtension("Application/PDF")).toBe(".pdf");
  });
  it("returns empty for unknown types", () => {
    expect(sickNoteExtension("text/plain")).toBe("");
    expect(sickNoteExtension("")).toBe("");
    expect(sickNoteExtension("constructor")).toBe("");
    expect(sickNoteExtension("__proto__")).toBe("");
  });
});

describe("messageFromErrorText", () => {
  it("returns the message from a JSON body", () => {
    expect(messageFromErrorText('{"message":"Sick note was deleted"}')).toBe("Sick note was deleted");
  });
  it("falls back for invalid JSON, missing or empty message", () => {
    expect(messageFromErrorText("not json")).toBe(SICK_NOTE_ERROR);
    expect(messageFromErrorText("{}")).toBe(SICK_NOTE_ERROR);
    expect(messageFromErrorText('{"message":""}')).toBe(SICK_NOTE_ERROR);
    expect(messageFromErrorText("null")).toBe(SICK_NOTE_ERROR);
  });
});

describe("saveSickNoteBlob", () => {
  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it("revokes the object URL only after the download has had time to start", () => {
    vi.useFakeTimers();
    const link = { href: "", download: "", click: vi.fn() };
    vi.stubGlobal("document", {
      createElement: vi.fn(() => link),
      body: { appendChild: vi.fn(), removeChild: vi.fn() },
    });
    vi.spyOn(URL, "createObjectURL").mockReturnValue("blob:sick-note");
    const revoke = vi.spyOn(URL, "revokeObjectURL").mockImplementation(() => undefined);

    saveSickNoteBlob(new Blob(["%PDF-1.7"], { type: "application/pdf" }), 42);

    expect(link.click).toHaveBeenCalledOnce();
    expect(link.href).toBe("blob:sick-note");
    expect(link.download).toBe("sick-note-42.pdf");
    expect(revoke).not.toHaveBeenCalled();
    vi.advanceTimersByTime(OBJECT_URL_REVOKE_DELAY_MS);
    expect(revoke).toHaveBeenCalledWith("blob:sick-note");
  });
});
